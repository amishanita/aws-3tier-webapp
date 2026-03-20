import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    api_spike: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "30s", target: 10 },
        { duration: "1m", target: 25 },
        { duration: "2m", target: 50 },
        { duration: "2m", target: 80 },
        { duration: "30s", target: 0 },
      ],
      gracefulStop: "30s",
    },
  },
};

const BASE_URL = __ENV.BASE_URL || "https://CHANGE_ME";

export default function () {
  const key = `k-${Math.floor(Math.random() * 2000)}`;
  const res = http.get(`${BASE_URL}/api/data?key=${key}`, { timeout: "30s" });

  check(res, {
    "status 200": (r) => r.status === 200,
  });

  // Keep the request pacing realistic.
  sleep(0.1);
}

