// @ts-nocheck
import { slackNotify } from "../src/curbImport";

global.fetch = jest.fn().mockResolvedValue({ ok: true });

describe("slackNotify", () => {
  it("returns early when webhook not set", async () => {
    delete process.env.SLACK_WEBHOOK_URL;
    await slackNotify("hello");
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it("sends POST when webhook set", async () => {
    (global.fetch as jest.Mock).mockClear();
    process.env.SLACK_WEBHOOK_URL = "https://hooks.slack.com/...";
    await slackNotify("msg");
    expect(global.fetch).toHaveBeenCalledWith(
      process.env.SLACK_WEBHOOK_URL,
      expect.objectContaining({ method: "POST" })
    );
  });
}); 