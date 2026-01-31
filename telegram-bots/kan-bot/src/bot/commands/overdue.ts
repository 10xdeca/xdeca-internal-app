import type { AuthContext } from "../middleware/auth.js";
import { getUserLink, getWorkspaceLink } from "../../db/queries.js";
import { createKanClient } from "../../api/kan-client.js";
import { formatCardList } from "../../utils/format.js";

export async function overdueCommand(ctx: AuthContext) {
  const userId = ctx.from?.id;
  const chatId = ctx.chat?.id;

  if (!userId || !chatId) {
    await ctx.reply("Could not identify user or chat.");
    return;
  }

  // Get user link
  const userLink = await getUserLink(userId);
  if (!userLink) {
    await ctx.reply(
      "You haven't linked your Kan account yet.\n\n" +
        "Use `/link <your-kan-api-key>` to connect your account.",
      { parse_mode: "Markdown" }
    );
    return;
  }

  // Get workspace link
  const workspaceLink = await getWorkspaceLink(chatId);
  if (!workspaceLink) {
    await ctx.reply(
      "This chat isn't linked to a Kan workspace yet.\n\n" +
        "Use `/start <workspace-slug>` to connect this chat.",
      { parse_mode: "Markdown" }
    );
    return;
  }

  const client = createKanClient(userLink.kanApiKey);

  try {
    const workspace = await client.getWorkspace(workspaceLink.workspacePublicId);
    const overdueTasks = await client.getOverdueCards(workspaceLink.workspacePublicId);

    if (overdueTasks.length === 0) {
      await ctx.reply(
        `No overdue tasks in *${workspaceLink.workspaceName}*`,
        { parse_mode: "Markdown" }
      );
      return;
    }

    // Sort by how overdue (most overdue first)
    overdueTasks.sort((a, b) => {
      const aDate = new Date(a.card.dueDate!).getTime();
      const bDate = new Date(b.card.dueDate!).getTime();
      return aDate - bDate;
    });

    const formattedList = formatCardList(overdueTasks, {
      workspaceSlug: workspace.slug,
    });

    await ctx.reply(
      `Overdue tasks in *${workspaceLink.workspaceName}* (${overdueTasks.length}):\n\n${formattedList}`,
      { parse_mode: "Markdown" }
    );
  } catch (error) {
    console.error("Error fetching overdue tasks:", error);
    await ctx.reply("Error fetching overdue tasks. Please try again.");
  }
}
