/**
 * Inject Datetime Plugin
 *
 * Prepends current date/time to every agent turn via before_prompt_build.
 * Reads timezone from agent config, falls back to UTC.
 */

import type { OpenClawPluginApi } from "openclaw/plugin-sdk";

type BeforePromptBuildEvent = {
  prompt: string;
  messages: unknown[];
};

type BeforePromptBuildResult = {
  systemPrompt?: string;
  prependContext?: string;
};

function getTimezone(config: unknown): string {
  try {
    const c = config as any;
    return c?.agents?.defaults?.userTimezone || "UTC";
  } catch {
    return "UTC";
  }
}

function getShortTz(timezone: string): string {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      timeZoneName: "short",
    }).formatToParts(new Date());
    const tzPart = parts.find((p) => p.type === "timeZoneName");
    return tzPart?.value || timezone;
  } catch {
    return timezone;
  }
}

export default function register(api: OpenClawPluginApi) {
  api.on(
    "before_prompt_build",
    async (_event: BeforePromptBuildEvent): Promise<BeforePromptBuildResult | void> => {
      try {
        const timezone = getTimezone(api.config);
        const shortTz = getShortTz(timezone);

        const now = new Date().toLocaleString("en-US", {
          timeZone: timezone,
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
          hour12: true,
        });

        return {
          prependContext: `[Current date/time: ${now} (${shortTz})]`,
        };
      } catch (err) {
        api.logger.warn?.(`[inject-datetime] Hook error: ${err}`);
        return;
      }
    },
  );
}
