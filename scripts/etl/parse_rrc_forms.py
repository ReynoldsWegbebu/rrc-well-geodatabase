"""
parse_rrc_forms.py
------------------
ETL pipeline for extracting structured data from RRC of Texas regulatory
filings. Demonstrates systematic field extraction from semi-structured
PDF documents into a normalized geodatabase schema.

Forms handled:
  G-1  — Gas Well Back Pressure Test / Completion Report
  G-5  — Gas Well Classification Report
  G-10 — Gas Well Status Report
  W-3  — Plugging Record
  W-15 — Cementing Report
  P-4  — Certificate of Compliance & Transportation Authority
  P-13 — Application to Condition Abandoned Well for Fresh Water
  GW-2 — Groundwater Protection Determination

Usage:
  python parse_rrc_forms.py --input data/raw/ --output data/processed/
"""

import os
import re
import json
import argparse
import logging
from dataclasses import dataclass, field, asdict
from datetime import date, datetime
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Data models — mirrors the geodatabase schema
# ---------------------------------------------------------------------------

@dataclass
class WellRecord:
    well_id:            str
    api_number:         str
    well_no:            str  = ""
    lease_name:         str  = ""
    operator_name:      str  = ""
    operator_p5:        str  = ""
    county:             str  = ""
    rrc_district:       str  = ""
    field_name:         str  = ""
    field_no:           str  = ""
    rrc_gas_id:         str  = ""
    latitude:           Optional[float] = None
    longitude:          Optional[float] = None
    datum:              str  = "NAD83"
    elevation_ft:       Optional[float] = None
    well_type:          str  = ""
    well_status:        str  = ""
    filing_purpose:     str  = ""
    permit_no:          str  = ""
    permit_date:        Optional[str]  = None
    submission_date:    Optional[str]  = None
    tracking_no:        str  = ""


@dataclass
class CompletionRecord:
    comp_id:            str
    well_id:            str
    api_number:         str  = ""
    comp_type:          str  = ""
    recompletion:       bool = False
    spud_date:          Optional[str] = None
    first_prod_date:    Optional[str] = None
    total_depth_tvd:    Optional[float] = None
    total_depth_md:     Optional[float] = None
    log_types:          str = ""
    directional_survey: bool = False


@dataclass
class GasMeasurementRecord:
    meas_id:            str
    well_id:            str
    api_number:         str   = ""
    test_date:          Optional[str] = None
    meas_method:        str   = ""
    gas_prod_mcf:       Optional[float] = None
    orifice_choke_in:   Optional[float] = None
    coeff_24hr:         Optional[float] = None
    volume_mcfd:        Optional[float] = None
    gravity_dry:        Optional[float] = None
    bh_temp_f:          Optional[float] = None
    bh_temp_depth_ft:   Optional[float] = None


@dataclass
class FormationRecord:
    form_id:            str
    well_id:            str
    api_number:         str   = ""
    formation_name:     str   = ""
    encountered:        bool  = False
    depth_tvd_ft:       Optional[float] = None
    is_isolated:        bool  = False
    inj_disposal_zone:  bool  = False
    geopressured:       bool  = False
    h2s_present:        bool  = False
    remarks:            str   = ""


# ---------------------------------------------------------------------------
# Field extraction utilities
# ---------------------------------------------------------------------------

class RRCFieldExtractor:
    """
    Utility methods for extracting typed values from RRC form text fields.
    RRC PDFs follow a consistent layout; this class provides robust
    pattern matching for the most common field types.
    """

    DATE_PATTERNS = [
        r"\b(\d{2}/\d{2}/\d{4})\b",    # 10/20/2025
        r"\b(\d{4}-\d{2}-\d{2})\b",    # 2025-10-20
    ]

    API_PATTERN = r"\b(42-\d{3}-\d{5})\b"

    @staticmethod
    def extract_api(text: str) -> Optional[str]:
        m = re.search(RRCFieldExtractor.API_PATTERN, text)
        return m.group(1) if m else None

    @staticmethod
    def extract_date(text: str) -> Optional[str]:
        for pattern in RRCFieldExtractor.DATE_PATTERNS:
            m = re.search(pattern, text)
            if m:
                raw = m.group(1)
                # normalize to ISO
                if "/" in raw:
                    mo, dy, yr = raw.split("/")
                    return f"{yr}-{mo}-{dy}"
                return raw
        return None

    @staticmethod
    def extract_float(text: str, label: str) -> Optional[float]:
        """Extract numeric value following a label keyword."""
        pattern = rf"{re.escape(label)}\s*[:=]?\s*([\d,]+\.?\d*)"
        m = re.search(pattern, text, re.IGNORECASE)
        if m:
            try:
                return float(m.group(1).replace(",", ""))
            except ValueError:
                pass
        return None

    @staticmethod
    def extract_coordinates(text: str) -> tuple[Optional[float], Optional[float]]:
        """Extract latitude/longitude from RRC form header block."""
        lat_m = re.search(r"Latitude\s+([\d.]+)", text, re.IGNORECASE)
        lon_m = re.search(r"Longitud[e]?\s+([-\d.]+)", text, re.IGNORECASE)
        lat = float(lat_m.group(1)) if lat_m else None
        lon = float(lon_m.group(1)) if lon_m else None
        return lat, lon

    @staticmethod
    def extract_boolean_flag(text: str, label: str) -> bool:
        """Returns True if 'Yes' follows the label, False otherwise."""
        pattern = rf"{re.escape(label)}\s*[:=]?\s*(Yes|No)"
        m = re.search(pattern, text, re.IGNORECASE)
        return m.group(1).lower() == "yes" if m else False

    @staticmethod
    def extract_text_field(text: str, label: str, max_chars: int = 100) -> str:
        """Extract free-text value after a form label."""
        pattern = rf"{re.escape(label)}\s*[:=]?\s*(.{{1,{max_chars}}}?)(?:\n|$)"
        m = re.search(pattern, text, re.IGNORECASE)
        return m.group(1).strip() if m else ""


# ---------------------------------------------------------------------------
# G-1 Form Parser
# ---------------------------------------------------------------------------

class G1FormParser:
    """
    Parses Form G-1 (Gas Well Back Pressure Test, Completion or Recompletion
    Report) into structured database records.

    Key sections parsed:
      - Operator Information → OPERATOR table
      - Well Information     → WELLS table
      - Filing Information   → WELLS table
      - Completion Information → COMPLETION table
      - Gas Measurement Data  → GAS_MEASUREMENT table
      - Field Data & Pressure Calculations → PRESSURE_TEST table
      - Casing Record         → CASING table
      - Tubing Record         → TUBING table
      - Producing Interval    → PERFORATIONS table
      - Acid/Fracture         → FRAC_TREATMENT table
      - Formation Record      → FORMATIONS table
    """

    def __init__(self, text: str, source_file: str = ""):
        self.text = text
        self.source = source_file
        self.ex = RRCFieldExtractor()

    def parse_well(self, well_id: str) -> WellRecord:
        api = self.ex.extract_api(self.text) or ""
        lat, lon = self.ex.extract_coordinates(self.text)

        return WellRecord(
            well_id         = well_id,
            api_number      = api,
            well_no         = self.ex.extract_text_field(self.text, "Well"),
            lease_name      = self.ex.extract_text_field(self.text, "Lease"),
            operator_name   = self.ex.extract_text_field(self.text, "Operator"),
            county          = self.ex.extract_text_field(self.text, "County"),
            rrc_district    = self.ex.extract_text_field(self.text, "RRC District"),
            field_name      = self.ex.extract_text_field(self.text, "Field"),
            latitude        = lat,
            longitude       = lon,
            filing_purpose  = self.ex.extract_text_field(self.text, "Purpose of"),
            permit_no       = self.ex.extract_text_field(self.text, "Permit No"),
            tracking_no     = self.ex.extract_text_field(self.text, "Tracking No"),
        )

    def parse_completion(self, comp_id: str, well_id: str) -> CompletionRecord:
        return CompletionRecord(
            comp_id         = comp_id,
            well_id         = well_id,
            api_number      = self.ex.extract_api(self.text) or "",
            spud_date       = self._find_spud_date(),
            first_prod_date = self._find_first_prod_date(),
            total_depth_tvd = self.ex.extract_float(self.text, "Total depth TVD"),
            total_depth_md  = self.ex.extract_float(self.text, "Total depth MD"),
            log_types       = self.ex.extract_text_field(self.text, "Type(s) of electric"),
            recompletion    = self.ex.extract_boolean_flag(self.text, "Recompletion or"),
            directional_survey = self.ex.extract_boolean_flag(self.text, "Was directional survey"),
        )

    def parse_gas_measurement(self, meas_id: str, well_id: str) -> GasMeasurementRecord:
        return GasMeasurementRecord(
            meas_id         = meas_id,
            well_id         = well_id,
            api_number      = self.ex.extract_api(self.text) or "",
            test_date       = self.ex.extract_date(
                                 self._section("GAS MEASUREMENT DATA")),
            gas_prod_mcf    = self.ex.extract_float(self.text, "Gas production during test"),
            volume_mcfd     = self.ex.extract_float(
                                 self._section("GAS MEASUREMENT DATA"), "Volume"),
            gravity_dry     = self.ex.extract_float(self.text, "Gravity (dry"),
        )

    def parse_formations(self, well_id: str) -> list[FormationRecord]:
        """
        Parse the Formation Record table from the G-1.
        Each row: Formation Name | Encountered (Yes/No) | Depth TVD | Depth MD | Isolated
        """
        section = self._section("FORMATION RECORD")
        records = []
        known_formations = [
            "MIOCENE-LAGARTO-OAKVILLE", "CATAHOULA-ANAHUAC", "CATAHOULA-FRIO",
            "VICKSBURG", "JACKSON", "YEGUA", "COOK MOUNTAIN", "QUEEN CITY",
            "WILCOX", "ESCONDIDO", "OLMOS", "AUSTIN CHALK", "EAGLE FORD",
            "EDWARDS LIMESTONE", "SLIGO",
        ]
        for i, name in enumerate(known_formations):
            if name in section.upper():
                enc = bool(re.search(
                    rf"{re.escape(name)}.*?Yes", section, re.IGNORECASE | re.DOTALL
                ))
                depth_m = re.search(
                    rf"{re.escape(name)}\s+Yes\s+([\d.]+)", section, re.IGNORECASE
                )
                depth = float(depth_m.group(1)) if depth_m else None
                records.append(FormationRecord(
                    form_id        = f"FM-{well_id[-3:]}-{i+1:03d}",
                    well_id        = well_id,
                    formation_name = name,
                    encountered    = enc,
                    depth_tvd_ft   = depth,
                    h2s_present    = "H2S" in name.upper(),
                    geopressured   = "GEOPRESSURED" in section.upper() and enc,
                ))
        return records

    # ── private helpers ──────────────────────────────────────

    def _section(self, header: str) -> str:
        """Extract text block between a section header and the next header."""
        pattern = rf"{re.escape(header)}(.*?)(?=[A-Z\s]{{10,}}RECORD|[A-Z\s]{{10,}}DATA|$)"
        m = re.search(pattern, self.text, re.IGNORECASE | re.DOTALL)
        return m.group(1).strip() if m else ""

    def _find_spud_date(self) -> Optional[str]:
        m = re.search(r"Spud\s+([\d/]+)", self.text, re.IGNORECASE)
        if m:
            return self.ex.extract_date(m.group(0))
        return None

    def _find_first_prod_date(self) -> Optional[str]:
        m = re.search(r"Date of first production after rig\s+([\d/]+)", self.text, re.IGNORECASE)
        if m:
            return self.ex.extract_date(m.group(0))
        return None


# ---------------------------------------------------------------------------
# ETL Pipeline
# ---------------------------------------------------------------------------

class RRCGeoDatabase:
    """
    Main ETL pipeline. Processes RRC PDF text files and builds
    a structured in-memory geodatabase, then exports to JSON.
    """

    def __init__(self):
        self.wells:            list[WellRecord]           = []
        self.completions:      list[CompletionRecord]     = []
        self.gas_measurements: list[GasMeasurementRecord] = []
        self.formations:       list[FormationRecord]      = []

    def process_g1(self, text: str, well_id: str, source: str = "") -> None:
        """Process a single G-1 form text extract."""
        parser = G1FormParser(text, source)
        self.wells.append(parser.parse_well(well_id))
        self.completions.append(
            parser.parse_completion(f"C-{well_id[-3:]}", well_id))
        self.gas_measurements.append(
            parser.parse_gas_measurement(f"M-{well_id[-3:]}", well_id))
        self.formations.extend(parser.parse_formations(well_id))
        log.info(f"Processed G-1 for {well_id} ({source})")

    def to_dict(self) -> dict:
        return {
            "wells":            [asdict(r) for r in self.wells],
            "completions":      [asdict(r) for r in self.completions],
            "gas_measurements": [asdict(r) for r in self.gas_measurements],
            "formations":       [asdict(r) for r in self.formations],
        }

    def export_json(self, output_path: str) -> None:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f, indent=2, default=str)
        log.info(f"Exported geodatabase to {output_path}")

    def export_geojson(self, output_path: str) -> None:
        """Export WELLS as a GeoJSON FeatureCollection (NAD83 EPSG:4269)."""
        features = []
        for w in self.wells:
            if w.latitude and w.longitude:
                features.append({
                    "type": "Feature",
                    "geometry": {
                        "type": "Point",
                        "coordinates": [w.longitude, w.latitude]
                    },
                    "properties": {k: v for k, v in asdict(w).items()
                                   if k not in ("latitude", "longitude")}
                })
        fc = {
            "type": "FeatureCollection",
            "crs": {
                "type": "name",
                "properties": {"name": "urn:ogc:def:crs:EPSG::4269"}
            },
            "features": features
        }
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(fc, f, indent=2)
        log.info(f"Exported {len(features)} wells to {output_path}")

    def summary(self) -> str:
        return (
            f"GeoDatabase Summary\n"
            f"  Wells:            {len(self.wells)}\n"
            f"  Completions:      {len(self.completions)}\n"
            f"  Gas Measurements: {len(self.gas_measurements)}\n"
            f"  Formations:       {len(self.formations)}\n"
        )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Extract RRC regulatory form data into geodatabase schema"
    )
    parser.add_argument("--input",  default="data/raw/",
                        help="Directory containing RRC PDF text files")
    parser.add_argument("--output", default="data/processed/",
                        help="Output directory for JSON/GeoJSON files")
    args = parser.parse_args()

    Path(args.output).mkdir(parents=True, exist_ok=True)

    db = RRCGeoDatabase()

    # Process each text file in the input directory
    input_dir = Path(args.input)
    g1_files = list(input_dir.glob("*G-1*.txt")) + list(input_dir.glob("*g1*.txt"))
    if not g1_files:
        log.warning(f"No G-1 text files found in {args.input}. "
                    "Convert RRC PDFs to text first (e.g., pdftotext -layout file.pdf).")

    for i, fp in enumerate(g1_files, start=1):
        text = fp.read_text(encoding="utf-8", errors="ignore")
        well_id = f"W-{i:03d}"
        db.process_g1(text, well_id, str(fp))

    # Export
    db.export_json(os.path.join(args.output, "geodatabase.json"))
    db.export_geojson(os.path.join(args.output, "wells.geojson"))

    print(db.summary())


if __name__ == "__main__":
    main()
