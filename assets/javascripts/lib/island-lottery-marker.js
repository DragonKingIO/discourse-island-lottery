export const ISLAND_LOTTERY_MARKER =
  /\[island-lottery\]([\s\S]*?)\[\/island-lottery\]/i;

export function parseIslandLotteryMarker(text) {
  const match = text?.match(ISLAND_LOTTERY_MARKER);
  if (!match) {
    return null;
  }

  const values = { raw: match[0] };
  let currentField;

  for (const line of match[1].split("\n")) {
    const field = line.match(
      /^\s*(prize|closes_at|winners_count|min_trust_level|max_trust_level)\s*:\s?(.*)$/i
    );

    if (field) {
      currentField = field[1].toLowerCase();
      values[currentField] = field[2].trim();
    } else if (currentField === "prize" && line.trim()) {
      values.prize = `${values.prize}\n${line.trim()}`;
    }
  }

  return values;
}

export function buildIslandLotteryMarker({
  prize,
  closesAt,
  winnersCount,
  minTrustLevel,
  maxTrustLevel,
}) {
  const safePrize = String(prize || "").replace(/\[\/island-lottery\]/gi, "");

  return [
    "[island-lottery]",
    `prize: ${safePrize}`,
    `closes_at: ${new Date(closesAt).toISOString()}`,
    `winners_count: ${winnersCount}`,
    `min_trust_level: ${minTrustLevel}`,
    `max_trust_level: ${maxTrustLevel}`,
    "[/island-lottery]",
  ].join("\n");
}
