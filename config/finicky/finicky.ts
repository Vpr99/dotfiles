import type { FinickyConfig } from "/Applications/Finicky.app/Contents/Resources/finicky.d.ts";

// Profile folder names, not display names: two profiles are both called "NPS",
// and Finicky matches display name first in random map order.
const personal = { name: "Google Chrome", profile: "Default" };
const nps = { name: "Google Chrome", profile: "Profile 1" };

const onDomain = (url: URL, ...domains: string[]) =>
  domains.some((d) => url.host === d || url.host.endsWith(`.${d}`));

export default {
  defaultBrowser: personal,
  handlers: [
    {
      match: (url) => onDomain(url, "northpole.security", "workshop.cloud", "meet.google.com"),
      browser: nps,
    },
    {
      match: (url) => onDomain(url, "github.com") && url.pathname.startsWith("/northpolesec"),
      browser: nps,
    },
  ],
} satisfies FinickyConfig;
