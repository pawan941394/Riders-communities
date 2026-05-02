import hashlib
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import urlopen
import xml.etree.ElementTree as ET

from apps.ev.models import EvLocation

KML_NS = {"kml": "http://www.opengis.net/kml/2.2"}


def _is_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"}


def _load_text(source: str) -> str:
    if _is_url(source):
        with urlopen(source) as response:
            return response.read().decode("utf-8")
    return Path(source).read_text(encoding="utf-8")


def _parse_coordinates(raw: str) -> tuple[float, float] | None:
    chunk = (raw or "").strip().split()[0] if raw else ""
    if not chunk:
        return None
    parts = [p for p in chunk.split(",") if p]
    if len(parts) < 2:
        return None
    try:
        lon = float(parts[0])
        lat = float(parts[1])
    except ValueError:
        return None
    return lat, lon


def _extract_extended_data(placemark: ET.Element) -> dict[str, str]:
    data: dict[str, str] = {}
    for data_node in placemark.findall(".//kml:ExtendedData/kml:Data", KML_NS):
        key = data_node.attrib.get("name", "").strip()
        value = (data_node.findtext("kml:value", "", KML_NS) or "").strip()
        if key:
            data[key] = value
    return data


def _extract_network_links(root: ET.Element) -> list[str]:
    links: list[str] = []
    for href in root.findall(".//kml:NetworkLink/kml:Link/kml:href", KML_NS):
        value = (href.text or "").strip()
        if value:
            links.append(value)
    return links


def _extract_placemark_items(root: ET.Element, source_url: str, source_name: str) -> list[dict]:
    items: list[dict] = []
    for placemark in root.findall(".//kml:Placemark", KML_NS):
        name = (placemark.findtext("kml:name", "", KML_NS) or "").strip() or "Unknown location"
        description = (placemark.findtext("kml:description", "", KML_NS) or "").strip()

        coordinates = (
            placemark.findtext(".//kml:Point/kml:coordinates", "", KML_NS)
            or placemark.findtext(".//kml:LineString/kml:coordinates", "", KML_NS)
            or placemark.findtext(".//kml:Polygon//kml:coordinates", "", KML_NS)
            or ""
        ).strip()
        parsed = _parse_coordinates(coordinates)
        if not parsed:
            continue
        lat, lon = parsed

        geometry_type = "Point"
        if placemark.find(".//kml:LineString", KML_NS) is not None:
            geometry_type = "LineString"
        elif placemark.find(".//kml:Polygon", KML_NS) is not None:
            geometry_type = "Polygon"

        extended = _extract_extended_data(placemark)
        address = (
            extended.get("address")
            or extended.get("Address")
            or extended.get("ADDRESS")
            or ""
        ).strip()

        placemark_id = placemark.attrib.get("id", "").strip()
        external_seed = f"{placemark_id}|{name}|{coordinates}|{source_url}"
        external_id = placemark_id or hashlib.sha1(external_seed.encode("utf-8")).hexdigest()[:24]

        items.append(
            {
                "source_name": source_name,
                "source_url": source_url,
                "external_id": external_id,
                "name": name,
                "description": description,
                "address": address,
                "latitude": lat,
                "longitude": lon,
                "geometry_type": geometry_type,
                "raw_coordinates": coordinates,
                "raw_extended_data": extended,
            }
        )
    return items


def import_kml(source: str, source_name: str = "kml") -> dict[str, int]:
    queue = [source]
    seen: set[str] = set()
    upserted = 0
    discovered_links = 0

    while queue:
        current = queue.pop(0)
        if current in seen:
            continue
        seen.add(current)

        xml_text = _load_text(current)
        root = ET.fromstring(xml_text)

        for link in _extract_network_links(root):
            discovered_links += 1
            if link not in seen:
                queue.append(link)

        for item in _extract_placemark_items(root, source_url=current, source_name=source_name):
            EvLocation.objects.update_or_create(
                source_url=item["source_url"],
                external_id=item["external_id"],
                defaults=item,
            )
            upserted += 1

    return {
        "sources_scanned": len(seen),
        "network_links_discovered": discovered_links,
        "locations_upserted": upserted,
    }
