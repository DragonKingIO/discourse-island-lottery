import { apiInitializer } from "discourse/lib/api";
import IslandLotteryCard from "../components/island-lottery-card";

function attachIslandLottery(cooked, helper) {
  if (!helper || cooked.classList.contains("d-editor-preview")) {
    return;
  }

  const post = helper.getModel();
  if (!post || post.post_number !== 1 || !post.topic?.island_lottery) {
    return;
  }

  const markers = [...cooked.querySelectorAll("div.island-lottery")].filter(
    (node) => !node.closest("blockquote")
  );
  const target = markers.shift() || document.createElement("div");

  for (const marker of markers) {
    marker.remove();
  }

  target.classList.add("island-lottery-embed");
  if (!target.parentElement) {
    cooked.append(target);
  }
  helper.renderGlimmer(target, IslandLotteryCard, { post }, { append: false });
}

export default apiInitializer((api) => {
  api.decorateCookedElement(attachIslandLottery, {
    id: "island-lottery-post-decorator",
    onlyStream: true,
  });
});
