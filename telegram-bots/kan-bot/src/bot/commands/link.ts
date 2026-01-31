import type { Context } from "grammy";
import { createKanClient } from "../../api/kan-client.js";
import {
  createUserLink,
  deleteUserLink,
  getUserLink,
  updateUserLink,
} from "../../db/queries.js";

export async function linkCommand(ctx: Context) {
  const userId = ctx.from?.id;
  const username = ctx.from?.username;
  const args = ctx.message?.text?.split(" ").slice(1).join(" ");

  if (!userId) {
    await ctx.reply("Could not identify user.");
    return;
  }

  // Check if in private chat for security
  if (ctx.chat?.type !== "private") {
    // Delete the message containing the API key for security
    try {
      await ctx.deleteMessage();
    } catch {
      // May not have permission to delete
    }

    await ctx.reply(
      "For security, please send your API key in a private message to me.\n\n" +
        "Click here to start a private chat: @" +
        ctx.me.username,
      { parse_mode: "Markdown" }
    );
    return;
  }

  if (!args) {
    const existingLink = await getUserLink(userId);
    if (existingLink) {
      await ctx.reply(
        `Your account is linked to: *${existingLink.kanUserEmail}*\n\n` +
          "To update your API key, use:\n" +
          "`/link <new-api-key>`\n\n" +
          "To unlink your account, use: `/unlinkme`",
        { parse_mode: "Markdown" }
      );
      return;
    }

    await ctx.reply(
      "Link your Kan account using your API key:\n\n" +
        "`/link <your-kan-api-key>`\n\n" +
        "You can find your API key in Kan under Settings > API.",
      { parse_mode: "Markdown" }
    );
    return;
  }

  const apiKey = args.trim();

  // Validate the API key by trying to get the user
  const client = createKanClient(apiKey);

  try {
    const user = await client.getMe();

    const existingLink = await getUserLink(userId);
    if (existingLink) {
      await updateUserLink(userId, {
        kanApiKey: apiKey,
        telegramUsername: username,
      });
      await ctx.reply(
        `API key updated for: *${user.email}*`,
        { parse_mode: "Markdown" }
      );
    } else {
      await createUserLink({
        telegramUserId: userId,
        telegramUsername: username,
        kanUserEmail: user.email,
        kanApiKey: apiKey,
      });
      await ctx.reply(
        `Account linked successfully!\n\n` +
          `Email: *${user.email}*\n` +
          `Name: ${user.name || "Not set"}\n\n` +
          "You can now use commands like `/mytasks` and `/done` in group chats.",
        { parse_mode: "Markdown" }
      );
    }
  } catch (error) {
    console.error("Error validating API key:", error);
    await ctx.reply(
      "Invalid API key. Please check your key and try again.\n\n" +
        "You can find your API key in Kan under Settings > API."
    );
  }
}

export async function unlinkMeCommand(ctx: Context) {
  const userId = ctx.from?.id;

  if (!userId) {
    await ctx.reply("Could not identify user.");
    return;
  }

  const existingLink = await getUserLink(userId);
  if (!existingLink) {
    await ctx.reply("Your account is not linked.");
    return;
  }

  await deleteUserLink(userId);
  await ctx.reply("Your Kan account has been unlinked.");
}
