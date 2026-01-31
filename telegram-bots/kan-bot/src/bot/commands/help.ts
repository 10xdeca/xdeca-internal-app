import type { Context } from "grammy";

export async function helpCommand(ctx: Context) {
  const helpText = `
*Kan Bot - Task Management*

*Setup Commands:*
\`/start <workspace>\` - Link this chat to a Kan workspace
\`/link <api-key>\` - Link your Telegram to your Kan account (send in DM)
\`/unlink\` - Unlink this chat from its workspace
\`/unlinkme\` - Unlink your personal Kan account

*Task Commands:*
\`/mytasks\` - View your assigned tasks
\`/overdue\` - View all overdue tasks in the workspace
\`/done <task-id>\` - Mark a task as complete
\`/comment <task-id> <text>\` - Add a comment to a task

*Tips:*
• Task IDs are shown when listing tasks (e.g., \`abc123def456\`)
• Link your account privately to keep your API key secure
• The bot will automatically remind about overdue tasks

*Getting your API key:*
Go to Kan → Settings → API to generate your API key.
`;

  await ctx.reply(helpText, { parse_mode: "Markdown" });
}
