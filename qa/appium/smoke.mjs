#!/usr/bin/env node

// Local WebDriver client for Appium XCUITest; no cloud account or npm package needed.
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { setTimeout as delay } from "node:timers/promises";

const appPath = process.env.MOVIEDEMO_APP_PATH;
const udid = process.env.MOVIEDEMO_SIM_UDID;
const server = (process.env.APPIUM_URL ?? "http://127.0.0.1:4723").replace(/\/$/, "");
const bundleId = "com.armando.moviedemo.swift.v2";
const driverOnly = process.argv.includes("--driver-only");
const reset = process.argv.includes("--reset");
const elementKey = "element-6066-11e4-a52e-4f735466cecf";

if (!appPath || !existsSync(appPath) || !udid) {
  throw new Error("Set MOVIEDEMO_APP_PATH to a built .app and MOVIEDEMO_SIM_UDID to an available iOS Simulator UDID.");
}
if (reset) {
  const installed = spawnSync("xcrun", ["simctl", "get_app_container", udid, bundleId, "app"], { stdio: "ignore" });
  if (installed.status === 0) {
    execFileSync("xcrun", ["simctl", "uninstall", udid, bundleId], { stdio: "ignore" });
  }
}

async function request(method, path, body, timeoutMs = 120_000) {
  const response = await fetch(`${server}${path}`, {
    method,
    headers: { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const payload = await response.json();
  if (!response.ok || payload.value?.error) {
    throw new Error(`${method} ${path}: ${payload.value?.message ?? response.statusText}`);
  }
  return payload.value;
}

let sessionId;
try {
  const session = await request("POST", "/session", {
    capabilities: {
      alwaysMatch: {
        platformName: "iOS",
        "appium:automationName": "XCUITest",
        "appium:udid": udid,
        "appium:app": appPath,
        "appium:bundleId": bundleId,
        "appium:noReset": true,
        "appium:newCommandTimeout": 120,
        "appium:processArguments": { args: ["-qa-fixture", "smoke-v1"] },
      },
    },
  }, 180_000);
  sessionId = session.sessionId;
  if (!sessionId) throw new Error("Appium did not return a session ID.");
  console.log(`Appium XCUITest session created on ${udid}.`);

  async function find(accessibilityId, timeoutMs = 20_000) {
    const deadline = Date.now() + timeoutMs;
    let lastError;
    while (Date.now() < deadline) {
      try {
        const element = await request("POST", `/session/${sessionId}/element`, {
          using: "accessibility id", value: accessibilityId,
        });
        return element[elementKey];
      } catch (error) {
        lastError = error;
        await delay(500);
      }
    }
    throw new Error(`Element '${accessibilityId}' missing after ${timeoutMs} ms. ${lastError?.message ?? ""}`);
  }

  async function tap(accessibilityId) {
    const element = await find(accessibilityId);
    await request("POST", `/session/${sessionId}/element/${element}/click`, {});
  }

  async function expectLabel(accessibilityId, expected, timeoutMs = 20_000) {
    const deadline = Date.now() + timeoutMs;
    let actual;
    while (Date.now() < deadline) {
      try {
        const element = await find(accessibilityId, 2_000);
        actual = await request("GET", `/session/${sessionId}/element/${element}/attribute/label`);
        if (actual === expected) return;
      } catch (error) {
        actual = error.message;
      }
      await delay(500);
    }
    throw new Error(`Expected '${accessibilityId}' label '${expected}', got '${actual}'.`);
  }

  await find("Popular Movies");
  console.log("Movies screen is visible.");
  if (driverOnly) {
    console.log("Driver-only smoke passed; app interactions were not tested.");
  } else {
    await tap("movies.row.9001");
    await find("movie.details.9001");
    await expectLabel("movie.favorite.toggle", "Add favorite");
    await tap("movie.favorite.toggle");
    await expectLabel("movie.favorite.toggle", "Remove favorite");
    await tap("tabs.favorites");
    await find("favorites.row.9001");
    await request("POST", `/session/${sessionId}/execute/sync`, {
      script: "mobile: terminateApp", args: [{ bundleId }],
    });
    await request("POST", `/session/${sessionId}/execute/sync`, {
      script: "mobile: launchApp", args: [{ bundleId, arguments: ["-qa-fixture", "smoke-v1"] }],
    });
    await find("favorites.row.9001");
    console.log("Favorite persisted after app relaunch; smoke passed.");
  }
} finally {
  if (sessionId) {
    await request("DELETE", `/session/${sessionId}`, undefined, 30_000)
      .catch(error => console.error(`Appium cleanup: ${error.message}`));
  }
}
