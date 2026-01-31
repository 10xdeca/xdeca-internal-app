import type { Context } from "grammy";
import { createKanClient } from "../../api/kan-client.js";
import {
  createWorkspaceLink,
  deleteWorkspaceLink,
  getWorkspaceLink,
  getUserLink,
} from "../../db/queries.js";

export async function startCommand(ctx: Context) {
  const chatId = ctx.chat?.id;
  const userId = ctx.from?.id;
  const args = ctx.message?.text?.split(" ").slice(1).join(" ");

  if (!chatId || !userId) {
    await ctx.reply("Could not identify chat or user.");
    return;
  }

  // Check if already linked
  const existingLink = await getWorkspaceLink(chatId);
  if (existingLink && !args) {
    await ctx.reply(
      `This chat is already linked to workspace: *${existingLink.workspaceName}*\n\n` +
        "To link to a different workspace, use:\n" +
        "`/start <workspace-slug-or-id>`\n\n" +
        "To unlink, use: `/unlink`",
      { parse_mode: "Markdown" }
    );
    return;
  }

  if (!args) {
    await ctx.reply(
      "Welcome to the Kan Bot!\n\n" +
        "To get started, link this chat to a Kan workspace:\n" +
        "`/start <workspace-slug-or-id>`\n\n" +
        "Example: `/start my-team`\n\n" +
        "You'll also need to link your personal account:\n" +
        "`/link <your-kan-api-key>`",
      { parse_mode: "Markdown" }
    );
    return;
  }

  // User needs to have linked their account first to look up workspaces
  const userLink = await getUserLink(userId);
  if (!userLink) {
    await ctx.reply(
      "You need to link your Kan account first.\n\n" +
        "Use `/link <your-kan-api-key>` to connect your account.\n\n" +
        "You can find your API key in Kan under Settings > API.",
      { parse_mode: "Markdown" }
    );
    return;
  }

  const client = createKanClient(userLink.kanApiKey);

  try {
    // Try to find the workspace
    const workspaces = await client.getWorkspaces();
    const workspace = workspaces.find(
      (w) =>
        w.publicId === args ||
        w.slug?.toLowerCase() === args.toLowerCase() ||
        w.name?.toLowerCase() === args.toLowerCase()
    );

    if (!workspace) {
      const workspaceList = workspaces
        .map((w) => `• ${w.name} (\`${w.slug}\`)`)
        .join("\n");

      await ctx.reply(
        `Workspace "${args}" not found.\n\n` +
          "Your available workspaces:\n" +
          workspaceList +
          "\n\nUse the slug or name to link.",
        { parse_mode: "Markdown" }
      );
      return;
    }

    // Remove existing link if any
    if (existingLink) {
      await deleteWorkspaceLink(chatId);
    }

    // Create the link
    await createWorkspaceLink({
      telegramChatId: chatId,
      workspacePublicId: workspace.publicId,
      workspaceName: workspace.name,
      createdByTelegramUserId: userId,
    });

    await ctx.reply(
      `Chat linked to workspace: *${workspace.name}*\n\n` +
        "Available commands:\n" +
        "• `/mytasks` - View your assigned tasks\n" +
        "• `/overdue` - View all overdue tasks\n" +
        "• `/done <task-id>` - Mark a task as complete\n" +
        "• `/comment <task-id> <text>` - Add a comment\n" +
        "• `/help` - Show all commands",
      { parse_mode: "Markdown" }
    );
  } catch (error) {
    console.error("Error in /start:", error);
    await ctx.reply(
      "Error connecting to Kan. Please check your API key is still valid."
    );
  }
}

export async function unlinkCommand(ctx: Context) {
  const chatId = ctx.chat?.id;

  if (!chatId) {
    await ctx.reply("Could not identify chat.");
    return;
  }

  const existingLink = await getWorkspaceLink(chatId);
  if (!existingLink) {
    await ctx.reply("This chat is not linked to any workspace.");
    return;
  }

  await deleteWorkspaceLink(chatId);
  await ctx.reply(
    `Unlinked from workspace: *${existingLink.workspaceName}*`,
    { parse_mode: "Markdown" }
  );
}
