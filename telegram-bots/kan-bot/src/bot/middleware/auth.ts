import type { Context, NextFunction } from "grammy";
import { getUserLink, getWorkspaceLink } from "../../db/queries.js";
import { createKanClient, type KanApiClient } from "../../api/kan-client.js";

export interface AuthContext extends Context {
  kanClient?: KanApiClient;
  workspacePublicId?: string;
  workspaceName?: string;
}

// Middleware that checks if the user has linked their Kan account
export async function requireUserLink(ctx: AuthContext, next: NextFunction) {
  const userId = ctx.from?.id;
  if (!userId) {
    await ctx.reply("Could not identify user.");
    return;
  }

  const userLink = await getUserLink(userId);
  if (!userLink) {
    await ctx.reply(
      "You haven't linked your Kan account yet.\n\n" +
        "Use /link <your-kan-api-key> to connect your account.\n\n" +
        "You can find your API key in Kan under Settings > API."
    );
    return;
  }

  ctx.kanClient = createKanClient(userLink.kanApiKey);
  return next();
}

// Middleware that checks if the chat has a linked workspace
export async function requireWorkspaceLink(ctx: AuthContext, next: NextFunction) {
  const chatId = ctx.chat?.id;
  if (!chatId) {
    await ctx.reply("Could not identify chat.");
    return;
  }

  const workspaceLink = await getWorkspaceLink(chatId);
  if (!workspaceLink) {
    await ctx.reply(
      "This chat isn't linked to a Kan workspace yet.\n\n" +
        "Use /start <workspace-id-or-slug> to connect this chat to a workspace."
    );
    return;
  }

  ctx.workspacePublicId = workspaceLink.workspacePublicId;
  ctx.workspaceName = workspaceLink.workspaceName;
  return next();
}

// Combined middleware for commands that need both
export async function requireAuth(ctx: AuthContext, next: NextFunction) {
  await requireUserLink(ctx, async () => {
    await requireWorkspaceLink(ctx, next);
  });
}
