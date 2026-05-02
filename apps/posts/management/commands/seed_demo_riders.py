"""Seed demo rider accounts + community posts for local QA."""

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.db import transaction

from apps.posts.models import Post
from apps.rider_auth.models import RiderProfile

User = get_user_model()

DEMO_PASSWORD = "demo123"

# Login uses phone_number + password (see /api/v1/auth/login).
DEMO_RIDERS = [
    {
        "username": "demo_rider_ajay",
        "email": "ajay.demo@riders.local",
        "first_name": "Ajay",
        "last_name": "Kumar",
        "phone": "9990000001",
        "city": "Delhi",
        "company": "Blinkit",
    },
    {
        "username": "demo_rider_priya",
        "email": "priya.demo@riders.local",
        "first_name": "Priya",
        "last_name": "Sharma",
        "phone": "9990000002",
        "city": "Noida",
        "company": "Zepto",
    },
    {
        "username": "demo_rider_vikram",
        "email": "vikram.demo@riders.local",
        "first_name": "Vikram",
        "last_name": "Singh",
        "phone": "9990000003",
        "city": "Gurgaon",
        "company": "Swiggy",
    },
    {
        "username": "demo_rider_sana",
        "email": "sana.demo@riders.local",
        "first_name": "Sana",
        "last_name": "Qureshi",
        "phone": "9990000004",
        "city": "Delhi",
        "company": "Zepto",
    },
    {
        "username": "demo_rider_rohit",
        "email": "rohit.demo@riders.local",
        "first_name": "Rohit",
        "last_name": "Yadav",
        "phone": "9990000005",
        "city": "Noida",
        "company": "Other",
    },
    {
        "username": "demo_rider_neha",
        "email": "neha.demo@riders.local",
        "first_name": "Neha",
        "last_name": "Gupta",
        "phone": "9990000006",
        "city": "Delhi",
        "company": "Blinkit",
    },
]

# Bodies use same convention as the app: [IssueType] prefix then blank line.
DEMO_POSTS = [
    {
        "author": "demo_rider_ajay",
        "city": "Delhi",
        "company": "Blinkit",
        "is_anonymous": False,
        "body": (
            "[Payment]\n\n"
            "Payout abhi tak account mein nahi aaya — last week se pending dikha raha hai. "
            "Support ticket raise ki hai par koi update nahi. Kisi ne Blinkit se solve kiya?"
        ),
    },
    {
        "author": "demo_rider_priya",
        "city": "Noida",
        "company": "Zepto",
        "is_anonymous": False,
        "body": (
            "[Account]\n\n"
            "Order cancel hone ke baad ID block ho gayi without warning. "
            "Documents submit kar diye, phir bhi reinstate nahi hua. Process kya hai?"
        ),
    },
    {
        "author": "demo_rider_vikram",
        "city": "Gurgaon",
        "company": "Swiggy",
        "is_anonymous": True,
        "body": (
            "[Safety]\n\n"
            "Raat ki shift pe stray dogs aur dark stretch — company se reflector jacket maangi thi, delay ho raha hai. "
            "Koi alternate route suggest kare Sector 56 side?"
        ),
    },
    {
        "author": "demo_rider_sana",
        "city": "Delhi",
        "company": "Zepto",
        "is_anonymous": False,
        "body": (
            "[Route]\n\n"
            "Metro construction ki wajah se maps galat route dikha rahe hain. "
            "CP area mein practical shortcut kaun use karta hai ab?"
        ),
    },
    {
        "author": "demo_rider_rohit",
        "city": "Noida",
        "company": "Other",
        "is_anonymous": False,
        "body": (
            "[Payment]\n\n"
            "Incentive slab samajh nahi aa raha — weekly statement aur app numbers match nahi kar rahe. "
            "Screenshot kahan se export kare?"
        ),
    },
    {
        "author": "demo_rider_neha",
        "city": "Delhi",
        "company": "Blinkit",
        "is_anonymous": False,
        "body": (
            "[Safety]\n\n"
            "Kal rain mein brake slip hua almost. Wet roads pe tips chahiye — tyre pressure kitna rakho?"
        ),
    },
    {
        "author": "demo_rider_ajay",
        "city": "Delhi",
        "company": "Blinkit",
        "is_anonymous": False,
        "body": (
            "[Account]\n\n"
            "Background verification dobara maang rahe hain jabki pehle clear tha. "
            "Kya ye normal hai ya profile glitch?"
        ),
    },
    {
        "author": "demo_rider_vikram",
        "city": "Gurgaon",
        "company": "Swiggy",
        "is_anonymous": False,
        "body": (
            "[Payment]\n\n"
            "Peak hour surge earnings kal reflect nahi hue wallet mein. "
            "36 ghante ho gaye — escalation ka best channel kya hai?"
        ),
    },
    {
        "author": "demo_rider_priya",
        "city": "Noida",
        "company": "Zepto",
        "is_anonymous": True,
        "body": (
            "[Route]\n\n"
            "Expressway toll daily kharch ho raha hai — reimbursement policy ka experience share karo."
        ),
    },
    {
        "author": "demo_rider_sana",
        "city": "Delhi",
        "company": "Zepto",
        "is_anonymous": False,
        "body": (
            "[Account]\n\n"
            "Device change ke baad OTP delay ho raha hai login pe. "
            "SIM same hai — kisi aur ko bhi hua?"
        ),
    },
]

DEMO_USERNAMES = [r["username"] for r in DEMO_RIDERS]


class Command(BaseCommand):
    help = (
        "Create demo rider users + RiderProfile rows and sample posts for QA. "
        "Login via API/app: phone = row phone, password = demo123. "
        "Re-run is skipped unless you pass --force (deletes demo users & their posts first)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            action="store_true",
            help="Delete existing demo riders (by username) and their data, then re-seed.",
        )

    def handle(self, *args, **options):
        force: bool = options["force"]

        if force:
            deleted, _ = User.objects.filter(username__in=DEMO_USERNAMES).delete()
            self.stdout.write(self.style.WARNING(f"--force: removed existing demo graph ({deleted} objects)."))

        existing_demo_users = User.objects.filter(username__in=DEMO_USERNAMES).count()
        existing_posts = Post.objects.filter(author__username__in=DEMO_USERNAMES).count()

        if existing_demo_users == len(DEMO_RIDERS) and existing_posts >= len(DEMO_POSTS) and not force:
            self.stdout.write(
                self.style.NOTICE(
                    "Demo seed already present (%s users, %s posts). Use --force to reset."
                    % (existing_demo_users, existing_posts)
                )
            )
            self._print_login_hint()
            return

        with transaction.atomic():
            users_by_username = {}
            for spec in DEMO_RIDERS:
                user, created = User.objects.get_or_create(
                    username=spec["username"],
                    defaults={
                        "email": spec["email"],
                        "first_name": spec["first_name"],
                        "last_name": spec["last_name"],
                    },
                )
                if created:
                    user.set_password(DEMO_PASSWORD)
                    user.save()
                    self.stdout.write(self.style.SUCCESS(f"Created user @{spec['username']}"))
                else:
                    user.email = spec["email"]
                    user.first_name = spec["first_name"]
                    user.last_name = spec["last_name"]
                    user.set_password(DEMO_PASSWORD)
                    user.save(update_fields=["email", "first_name", "last_name", "password"])
                    self.stdout.write(self.style.NOTICE(f"Updated user @{spec['username']}"))

                profile, pc = RiderProfile.objects.update_or_create(
                    user=user,
                    defaults={
                        "phone_number": spec["phone"],
                        "city": spec["city"],
                        "rider_company": spec["company"],
                        "preferred_language": "en",
                    },
                )
                if pc:
                    self.stdout.write(f"  RiderProfile created ({spec['phone']})")
                else:
                    self.stdout.write(f"  RiderProfile updated ({spec['phone']})")

                users_by_username[spec["username"]] = user

            bodies_existing = set(
                Post.objects.filter(author__username__in=DEMO_USERNAMES).values_list("body", flat=True),
            )
            posts_created = 0
            for row in DEMO_POSTS:
                author = users_by_username[row["author"]]
                body = row["body"].strip()
                if body in bodies_existing:
                    continue
                Post.objects.create(
                    author=author,
                    body=body,
                    city=row["city"],
                    company=row["company"],
                    is_anonymous=row["is_anonymous"],
                )
                bodies_existing.add(body)
                posts_created += 1

            self.stdout.write(self.style.SUCCESS(f"Posts created: {posts_created} (skipped duplicates by body text)."))

        self._print_login_hint()

    def _print_login_hint(self):
        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS("Demo login (phone + password demo123):"))
        for spec in DEMO_RIDERS:
            self.stdout.write(
                f"  {spec['phone']} - {spec['first_name']} {spec['last_name']} ({spec['city']}, {spec['company']})"
            )
        self.stdout.write("")
        self.stdout.write("Example: POST /api/v1/auth/login with {\"phone_number\":\"9990000001\",\"password\":\"demo123\"}")
