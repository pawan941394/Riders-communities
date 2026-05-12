import Image from "next/image";
import styles from "./page.module.css";

const previews = [
  {
    src: "/landing/1platform-overview.png",
    alt: "Rider community feed screen",
    title: "Community Feed",
  },
  {
    src: "/landing/create-post-screen.png",
    alt: "Create post screen in app",
    title: "Post Issue",
  },
  {
    src: "/landing/support-screen.png",
    alt: "Help and support screen",
    title: "Help & Support",
  },
  {
    src: "/landing/ev-screen.png",
    alt: "EV charging station screen",
    title: "EV Charging",
  },
];

const issueTypes = ["Payout", "Account Block", "Safety", "Route", "App Bug"];
const playStoreUrl =
  "https://play.google.com/store/apps/details?id=com.ridermanch.app";

export default function Home() {
  return (
    <div className={styles.page}>
      <header className={styles.navbar}>
        <a href="#" className={styles.logo}>
          <Image
            src="/icons/icon.png"
            alt="Ride with Garv logo"
            width={52}
            height={52}
            className={styles.logoIcon}
            priority
          />
          <div>
            <strong>Ride with Garv</strong>
            <small>Rider community app</small>
          </div>
        </a>
        <nav className={styles.navLinks}>
          <span className={styles.headerBadge}>Delhi NCR riders</span>
          <a
            href={playStoreUrl}
            className={styles.downloadTop}
            target="_blank"
            rel="noopener noreferrer"
          >
            Download App
          </a>
        </nav>
      </header>

      <main className={styles.main}>
        <section className={styles.hero}>
          <div className={styles.heroContent}>
            <div className={styles.heroGrid}>
              <div>
                <p className={styles.eyebrow}>Riders ka apna social app</p>
                <h1>Apni problem post karo. Dusre riders se jawab pao.</h1>
                <p className={styles.heroCopy}>
                  Ride with Garv delivery riders ke liye community app hai.
                  Yahan rider payout, account block, safety, route, app bug aur
                  EV charging ki problem share kar sakta hai. Saath me rider EV
                  charging station dekh sakta hai, rent EV plan compare kar
                  sakta hai, aur buy/finance option bhi explore kar sakta hai.
                </p>
                <div className={styles.actions}>
                  <a
                    href={playStoreUrl}
                    className={styles.primaryAction}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Download App
                  </a>
                  <a href="#ev-support" className={styles.secondaryAction}>
                    EV Options Dekho
                  </a>
                </div>
              </div>

              <article className={styles.heroFeed}>
                <div className={styles.feedHeader}>
                  <span>R</span>
                  <div>
                    <strong>Rider, Gurgaon</strong>
                    <p>Blinkit - abhi post kiya</p>
                  </div>
                  <em>Help</em>
                </div>
                <p className={styles.feedPost}>
                  Payment hold hai aur support se reply nahi aa raha. Kisi rider
                  ne ye solve kiya hai kya?
                </p>
                <div className={styles.feedTags}>
                  <span># Payout</span>
                  <span>Related company: Blinkit</span>
                  <span>Gurgaon</span>
                </div>
                <div className={styles.feedActions}>
                  <span>12 replies</span>
                  <span>Helpful</span>
                  <span>Translate</span>
                </div>
              </article>
            </div>

            <div className={styles.heroSteps}>
              <div>
                <p>1</p>
                <span>Problem likho</span>
              </div>
              <div>
                <p>2</p>
                <span>City aur company select karo</span>
              </div>
              <div>
                <p>3</p>
                <span>EV charging, rent aur buy option dekho</span>
              </div>
            </div>

            <div className={styles.heroEvStrip}>
              <span>EV Charging</span>
              <span>Rent EV</span>
              <span>Buy EV</span>
              <strong>Rider ke daily kaam ke liye EV support bhi included.</strong>
            </div>
          </div>
        </section>

        <section id="community" className={styles.communityBand}>
          <div className={styles.sectionHeading}>
            <p>Simple aur useful</p>
            <h2>Rider ki daily problem ke liye social feed.</h2>
          </div>
          <div className={styles.communityLayout}>
            <article className={styles.feedMock}>
              <div className={styles.feedItem}>
                <div className={styles.feedHeader}>
                  <span>P</span>
                  <div>
                    <strong>Pawan Kumar, Delhi</strong>
                    <p>Zepto - 2d ago</p>
                  </div>
                  <em>Delhi</em>
                </div>
                <p className={styles.feedPost}>
                  Device change ke baad OTP delay ho raha hai login pe. SIM same
                  hai. Kisi aur ko bhi hua?
                </p>
                <div className={styles.feedTags}>
                  <span>Related company: Zepto</span>
                  <span># Account</span>
                </div>
                <div className={styles.feedActions}>
                  <span>8 replies</span>
                  <span>Like (1)</span>
                  <span>Translate</span>
                </div>
              </div>

              <div className={styles.feedItem}>
                <div className={styles.feedHeader}>
                  <span>R</span>
                  <div>
                    <strong>Rohit Yadav, Gurgaon</strong>
                    <p>Blinkit - 5h ago</p>
                  </div>
                  <em>Gurgaon</em>
                </div>
                <p className={styles.feedPost}>
                  Payment settlement kal se pending hai. Kya support ticket ke
                  baad jaldi reply milta hai?
                </p>
                <div className={styles.feedTags}>
                  <span>Related company: Blinkit</span>
                  <span># Payout</span>
                </div>
                <div className={styles.feedActions}>
                  <span>14 replies</span>
                  <span>Helpful</span>
                  <span>Translate</span>
                </div>
              </div>
            </article>
            <div className={styles.issueCloud}>
              <div className={styles.issueCopy}>
                <p>Live rider help</p>
                <h3>Problem akeli nahi rahegi. Community reply karegi.</h3>
                <div className={styles.issueStats}>
                  <span>Delhi NCR</span>
                  <span>Hindi + English</span>
                  <span>Anonymous post</span>
                </div>
              </div>
              <div className={styles.issueVisual}>
                <Image
                  src="/landing/create-post-screen.png"
                  alt="Create rider issue post screen"
                  fill
                  sizes="(max-width: 900px) 80vw, 280px"
                  className={styles.issueImage}
                />
              </div>
              <div className={styles.replyStack}>
                <div>
                  <strong>Rider reply</strong>
                  <p>Ticket ID ke saath company tag karo, jaldi help milti hai.</p>
                </div>
                <div>
                  <strong>Support path</strong>
                  <p>Account block ya payout issue ko correct topic me bhejo.</p>
                </div>
              </div>
              <div className={styles.issueChips}>
                {issueTypes.map((type) => (
                  <span key={type}>{type}</span>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className={styles.featureStrip}>
          <article>
            <h3>Rider Community Feed</h3>
            <p>
              Delhi, Noida, Gurgaon ke riders ek jagah problem aur solution
              share karte hain.
            </p>
          </article>
          <article>
            <h3>Photo ke saath post</h3>
            <p>Rider text ya image ke saath apna issue post kar sakta hai.</p>
          </article>
          <article>
            <h3>Anonymous option</h3>
            <p>Jab zaroorat ho, rider apna naam hide karke bhi post kar sakta hai.</p>
          </article>
        </section>

        <section id="ev-support" className={styles.evSection}>
          <div className={styles.evContent}>
            <div className={styles.sectionHeading}>
              <p>EV Support Hub</p>
              <h2>Charging, rent aur buy EV bhi app me milega.</h2>
            </div>
            <p className={styles.evIntro}>
              Delivery riders ke liye EV sirf vehicle nahi, daily earning ka
              tool hai. Isliye app me charging station, rent plan aur buy/finance
              partner ka option clear rakha gaya hai.
            </p>
            <div className={styles.evCards}>
              <article>
                <span>Charge</span>
                <h3>Nearest EV Charging</h3>
                <p>City filter aur location ke hisaab se charging point dekho.</p>
              </article>
              <article>
                <span>Rent</span>
                <h3>Rent EV Plans</h3>
                <p>Daily ya weekly rent plans compare karke interest bhejo.</p>
              </article>
              <article>
                <span>Buy</span>
                <h3>Buy EV / Finance</h3>
                <p>Partner options, EMI, down payment aur documents check karo.</p>
              </article>
            </div>
          </div>
          <div className={styles.evPhone}>
            <Image
              src="/landing/ev-screen.png"
              alt="EV charging screen in Ride with Garv app"
              fill
              sizes="(max-width: 900px) 78vw, 320px"
              className={styles.evPhoneImage}
            />
          </div>
        </section>

        <section id="previews" className={styles.previews}>
          <div className={styles.sectionHeading}>
            <p>App ke real screens</p>
            <h2>Rider ko samajh aaye, isliye flow simple hai.</h2>
          </div>
          <div className={styles.previewGrid}>
            {previews.map((item) => (
              <article className={styles.previewCard} key={item.src}>
                <div className={styles.previewImageWrap}>
                  <Image
                    src={item.src}
                    alt={item.alt}
                    fill
                    sizes="(max-width: 740px) 100vw, (max-width: 1100px) 50vw, 25vw"
                    className={styles.previewImage}
                  />
                </div>
                <p>{item.title}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="download" className={styles.download}>
          <div>
            <p className={styles.downloadLabel}>Download App</p>
            <h2>Join karo before your next shift.</h2>
            <p>
              Problem share karo, riders se help lo, EV charging dekho, aur
              support ko message bhejo.
            </p>
          </div>
          <div className={styles.storeActions}>
            <a
              href={playStoreUrl}
              className={styles.primaryAction}
              target="_blank"
              rel="noopener noreferrer"
            >
              Google Play
            </a>
          </div>
        </section>
      </main>
    </div>
  );
}
