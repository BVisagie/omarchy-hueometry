// The six orb colours of the Lost Jungle Temple, and the carved symbol each
// one shows in symbols mode. The base colours are the Okabe-Ito set, which
// stays distinct under the common kinds of colour blindness; they also differ
// in lightness. tools/palette/check.py checks both.

export const ORBS = [
  { name: "sun", base: "#F0E442", light: "#FFF9B8", dark: "#A8950E", symbol: "star" },
  { name: "sky", base: "#56B4E9", light: "#C4EBFF", dark: "#1C6E9E", symbol: "circle" },
  { name: "jade", base: "#009E73", light: "#6FE6C0", dark: "#005A41", symbol: "leaf" },
  { name: "ember", base: "#D55E00", light: "#FFA866", dark: "#7A3500", symbol: "triangle" },
  { name: "lagoon", base: "#0072B2", light: "#5FB2EE", dark: "#003A5C", symbol: "square" },
  { name: "orchid", base: "#CC79A7", light: "#F7C8E2", dark: "#7E3C62", symbol: "diamond" },
];

export function orb(i) {
  return ORBS[((i % ORBS.length) + ORBS.length) % ORBS.length];
}
