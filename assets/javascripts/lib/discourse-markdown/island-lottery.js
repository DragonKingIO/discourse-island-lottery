const rule = {
  tag: "island-lottery",

  wrap(token) {
    token.attrs = [["class", "island-lottery"]];
    return true;
  },
};

export function setup(helper) {
  helper.allowList(["div.island-lottery"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.island_lottery = !!siteSettings.island_lottery_enabled;
  });

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("island-lottery", rule);
  });
}
