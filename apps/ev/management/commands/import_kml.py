from django.core.management.base import BaseCommand, CommandError

from apps.ev.kml_importer import import_kml


class Command(BaseCommand):
    help = "Import EV locations from a KML file/URL (supports NetworkLink)."

    def add_arguments(self, parser):
        parser.add_argument("source", type=str, help="Local .kml path or remote URL")
        parser.add_argument("--source-name", type=str, default="kml", help="Source label in DB")

    def handle(self, *args, **options):
        source: str = options["source"]
        source_name: str = options["source_name"]
        try:
            result = import_kml(source=source, source_name=source_name)
        except Exception as exc:
            raise CommandError(f"KML import failed: {exc}") from exc

        self.stdout.write(
            self.style.SUCCESS(
                "Import complete: "
                f"sources_scanned={result['sources_scanned']}, "
                f"network_links_discovered={result['network_links_discovered']}, "
                f"locations_upserted={result['locations_upserted']}"
            )
        )
