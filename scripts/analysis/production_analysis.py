"""
production_analysis.py
-----------------------
Petroleum data analysis for the Killam Oil Co. RRC District 04 well portfolio.
Demonstrates GIS analyst skills: data wrangling, spatial analysis, and
production engineering metrics.

Outputs:
  - IP gas comparison chart (console + PNG)
  - Pressure analysis summary
  - Formation depth profile
  - Well performance metrics table

Usage:
  python scripts/analysis/production_analysis.py
"""

import json
import math
import statistics
from pathlib import Path
from dataclasses import dataclass
from typing import Optional


# ---------------------------------------------------------------------------
# Well data (matches geodatabase seed records)
# ---------------------------------------------------------------------------

WELLS = [
    {
        "well_id":        "W-001",
        "api":            "42-479-45194",
        "lease":          "Nido Ranch 18H",
        "county":         "Webb",
        "status":         "Producing",
        "field":          "Hawkville (Austin Chalk)",
        "comp_type":      "New Well",
        "tvd_ft":         10863,
        "md_ft":          19043,
        "ip_mcfd":        11252.0,
        "siwh_psia":      5714.0,
        "flowing_psia":   4667.0,
        "choke":          "26/64",
        "choke_in":       26/64,
        "gas_gravity":    0.595,
        "water_bbl":      1269.0,
        "latitude":       None,           # Not in public filing
        "longitude":      None,
        "producing_zone": "Austin Chalk",
        "perf_from_ft":   11076.0,
        "perf_to_ft":     18914.0,
        "frac":           True,
    },
    {
        "well_id":        "W-002",
        "api":            "42-427-34736",
        "lease":          "I.V. Montalvo C #49",
        "county":         "Starr",
        "status":         "Producing",
        "field":          "Sun North (Vicksburg)",
        "comp_type":      "Recompletion",
        "tvd_ft":         6842,
        "md_ft":          None,
        "ip_mcfd":        492.0,
        "siwh_psia":      1750.0,
        "flowing_psia":   750.0,
        "choke":          "12/64",
        "choke_in":       12/64,
        "gas_gravity":    0.628,
        "water_bbl":      0.0,
        "latitude":       26.705160,
        "longitude":      -98.481645,
        "producing_zone": "Vicksburg",
        "perf_from_ft":   5200.0,
        "perf_to_ft":     5205.0,
        "frac":           False,
    },
    {
        "well_id":        "W-003",
        "api":            "42-479-39100",
        "lease":          "K&H Fee Porcion 1701",
        "county":         "Webb",
        "status":         "P&A",
        "field":          "Del Mar (Lobo Cons.)",
        "comp_type":      "Abandoned Producer",
        "tvd_ft":         6603,
        "md_ft":          None,
        "ip_mcfd":        None,
        "siwh_psia":      None,
        "flowing_psia":   None,
        "choke":          None,
        "choke_in":       None,
        "gas_gravity":    None,
        "water_bbl":      None,
        "latitude":       27.642504,
        "longitude":      -99.475177,
        "producing_zone": "Del Mar/Lobo",
        "perf_from_ft":   None,
        "perf_to_ft":     None,
        "frac":           False,
    },
]

FORMATIONS = [
    # Nido Ranch 18H
    {"well_id":"W-001","formation":"Wilcox",         "tvd_ft":4617,  "isolated":True,  "h2s":False,"producing":False},
    {"well_id":"W-001","formation":"Escondido",      "tvd_ft":5423,  "isolated":True,  "h2s":True, "producing":False},
    {"well_id":"W-001","formation":"Olmos",          "tvd_ft":6385,  "isolated":True,  "h2s":False,"producing":False},
    {"well_id":"W-001","formation":"Austin Chalk",   "tvd_ft":10513, "isolated":True,  "h2s":False,"producing":True},
    # I.V. Montalvo C #49
    {"well_id":"W-002","formation":"Miocene/Oakville","tvd_ft":0,    "isolated":False, "h2s":True, "producing":False},
    {"well_id":"W-002","formation":"Catahoula",      "tvd_ft":1310,  "isolated":True,  "h2s":False,"producing":False},
    {"well_id":"W-002","formation":"Catahoula-Frio", "tvd_ft":3670,  "isolated":True,  "h2s":False,"producing":False},
    {"well_id":"W-002","formation":"Vicksburg",      "tvd_ft":5680,  "isolated":True,  "h2s":False,"producing":True},
]


# ---------------------------------------------------------------------------
# Analysis functions
# ---------------------------------------------------------------------------

def drawdown_pct(siwh: float, flowing: float) -> float:
    """Pressure drawdown as % of SIWH — key reservoir deliverability metric."""
    return round((siwh - flowing) / siwh * 100, 1)


def deliverability_index(ip_mcfd: float, drawdown: float) -> float:
    """
    Simplified Deliverability Index (DI) = IP / Drawdown pressure.
    Used to compare well productivity independent of drawdown magnitude.
    Units: MCF/day/psi
    """
    return round(ip_mcfd / drawdown, 2)


def lateral_length_ft(tvd: float, md: float) -> Optional[float]:
    """Estimate horizontal lateral length from TVD and total MD."""
    if md and tvd:
        # Simplified: assumes vertical section ≈ TVD, remainder is lateral
        return round(md - tvd, 0)
    return None


def perf_interval_ft(perf_from: float, perf_to: float) -> float:
    return round(perf_to - perf_from, 0)


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate great-circle distance between two coordinate pairs (km)."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
    return round(2 * R * math.asin(math.sqrt(a)), 2)


def bar_chart(label: str, value: float, max_val: float, width: int = 40) -> str:
    filled = int((value / max_val) * width)
    bar = "█" * filled + "░" * (width - filled)
    return f"  {label:<28} [{bar}] {value:,.0f}"


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def run_analysis():
    print("=" * 72)
    print("  KILLAM OIL CO. — RRC DISTRICT 04 WELL PORTFOLIO ANALYSIS")
    print("  Operator #460054 | 3 Wells | Webb & Starr Counties, Texas")
    print("=" * 72)

    producing = [w for w in WELLS if w["ip_mcfd"] is not None]

    # ── 1. IP Gas Production Comparison ─────────────────────────────────────
    print("\n📊  INITIAL POTENTIAL GAS PRODUCTION (MCF/day)\n")
    max_ip = max(w["ip_mcfd"] for w in producing)
    for w in WELLS:
        ip = w["ip_mcfd"] or 0
        print(bar_chart(w["lease"], ip, max_ip))

    total_ip = sum(w["ip_mcfd"] for w in producing)
    print(f"\n  Portfolio Total IP:  {total_ip:,.0f} MCF/day")
    print(f"  Producing Wells:     {len(producing)}")

    # ── 2. Pressure Analysis ─────────────────────────────────────────────────
    print("\n\n🔬  WELLHEAD PRESSURE ANALYSIS\n")
    print(f"  {'Well':<28} {'SIWH (psia)':>12} {'Flowing (psia)':>15} {'Drawdown %':>11} {'DI (MCF/d/psi)':>15}")
    print(f"  {'-'*28} {'-'*12} {'-'*15} {'-'*11} {'-'*15}")

    for w in producing:
        dd = drawdown_pct(w["siwh_psia"], w["flowing_psia"])
        di = deliverability_index(w["ip_mcfd"], w["siwh_psia"] - w["flowing_psia"])
        print(f"  {w['lease']:<28} {w['siwh_psia']:>12,.0f} {w['flowing_psia']:>15,.0f} {dd:>10.1f}% {di:>15.2f}")

    # ── 3. Well Geometry ─────────────────────────────────────────────────────
    print("\n\n📐  WELL GEOMETRY & COMPLETION\n")
    print(f"  {'Well':<28} {'TVD (ft)':>10} {'MD (ft)':>10} {'Lateral (ft)':>13} {'Perf Interval':>14} {'Frac':>6}")
    print(f"  {'-'*28} {'-'*10} {'-'*10} {'-'*13} {'-'*14} {'-'*6}")

    for w in WELLS:
        tvd  = w["tvd_ft"] or 0
        md   = w["md_ft"]
        lat  = lateral_length_ft(tvd, md)
        perf = None
        if w["perf_from_ft"] and w["perf_to_ft"]:
            perf = perf_interval_ft(w["perf_from_ft"], w["perf_to_ft"])
        print(
            f"  {w['lease']:<28} "
            f"{tvd:>10,} "
            f"{md or 'N/A':>10} "
            f"{lat or 'N/A':>13} "
            f"{str(int(perf))+' ft' if perf else 'N/A':>14} "
            f"{'Yes' if w['frac'] else 'No':>6}"
        )

    # ── 4. Formation Profile ─────────────────────────────────────────────────
    print("\n\n🌍  FORMATION DEPTH PROFILE (encountered formations only)\n")
    encountered = [f for f in FORMATIONS if f["tvd_ft"] > 0]
    encountered.sort(key=lambda x: (x["well_id"], x["tvd_ft"]))

    current_well = None
    for f in encountered:
        if f["well_id"] != current_well:
            well = next(w for w in WELLS if w["well_id"] == f["well_id"])
            print(f"\n  ▶ {well['lease']} ({well['api']})")
            current_well = f["well_id"]
        flags = []
        if f["producing"]:  flags.append("PRODUCING ZONE")
        if f["isolated"]:   flags.append("isolated")
        if f["h2s"]:        flags.append("H2S")
        flag_str = "  [" + ", ".join(flags) + "]" if flags else ""
        print(f"      {f['tvd_ft']:>6,} ft TVD  —  {f['formation']}{flag_str}")

    # ── 5. Spatial Analysis ───────────────────────────────────────────────────
    print("\n\n📍  SPATIAL ANALYSIS\n")
    # Only W-002 and W-003 have known coordinates in this dataset
    w2 = next(w for w in WELLS if w["well_id"] == "W-002")
    w3 = next(w for w in WELLS if w["well_id"] == "W-003")

    if all([w2["latitude"], w3["latitude"]]):
        dist = haversine_km(
            w2["latitude"], w2["longitude"],
            w3["latitude"], w3["longitude"]
        )
        print(f"  Distance W-002 ↔ W-003:  {dist:.1f} km  ({dist*0.621371:.1f} mi)")

    # Laredo reference point
    laredo_lat, laredo_lon = 27.5064, -99.5067
    for w in WELLS:
        if w["latitude"]:
            d = haversine_km(w["latitude"], w["longitude"], laredo_lat, laredo_lon)
            print(f"  {w['lease']:<28} → Laredo:  {d:.1f} km ({d*0.621371:.1f} mi)")

    # ── 6. Portfolio Summary ─────────────────────────────────────────────────
    print("\n\n📋  PORTFOLIO SUMMARY\n")
    avg_tvd  = statistics.mean(w["tvd_ft"] for w in WELLS)
    counties = set(w["county"] for w in WELLS)
    zones    = set(w["producing_zone"] for w in WELLS if w["status"] == "Producing")

    summary = {
        "Total Wells":                  len(WELLS),
        "Producing Wells":              len(producing),
        "P&A Wells":                    sum(1 for w in WELLS if w["status"] == "P&A"),
        "Total IP Gas (MCF/day)":       f"{total_ip:,.0f}",
        "Avg Well Depth TVD (ft)":      f"{avg_tvd:,.0f}",
        "Deepest Well TVD (ft)":        f"{max(w['tvd_ft'] for w in WELLS):,}",
        "Counties":                     ", ".join(sorted(counties)),
        "Producing Formations":         ", ".join(sorted(zones)),
        "Wells with Frac Treatment":    sum(1 for w in WELLS if w["frac"]),
        "Formation Tops Recorded":      len(FORMATIONS),
    }

    for k, v in summary.items():
        print(f"  {k:<35} {v}")

    print("\n" + "=" * 72)
    print("  Analysis complete.")
    print("=" * 72 + "\n")


if __name__ == "__main__":
    run_analysis()
