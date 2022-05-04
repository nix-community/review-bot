import { LogService, MatrixClient, MentionPill, MessageEvent, MessageEventContent } from "matrix-bot-sdk";
import { Octokit } from "octokit";
import config from "../config";
import { spawn } from "child_process";
import * as fs from "fs/promises";
import { join } from "path";
import { createConnection as connectTcp } from "net";

export async function runPrCommand(roomId: string, event: MessageEvent<MessageEventContent>, args: string[], client: MatrixClient) {
    const octokit = new Octokit({
        auth: config.githubToken,
        userAgent: "review-bot (https://github.com/nix-community/review-bot)"
    });
    LogService.debug("PrCommand", `I am logged in as ${(await octokit.rest.users.getAuthenticated()).data.login} on GitHub`);

    // The first argument is always going to be us, so get the second argument instead.
    args.shift();
    const prIds = args.map(x => parseInt(x.replace(/[^\d]/, ""), 10));

    if (prIds.some(id => isNaN(id))) {
        throw new Error("Invalid arguments");
    }

    const { owner, repo } = config.nixpkgsRepo;

    LogService.debug("PrCommand", "acquiring PR info");
    const prInfo = (await Promise.all(prIds
        .map(prId => octokit.rest.pulls.get({ owner, repo, pull_number: prId }))))
        .map(res => res.data);

    const prInfoText = prInfo.map(pr => `- #${pr.number}: ${pr.title}`).join("\n");
    LogService.debug("PrCommand", "acquired PR info");
    const mention = await MentionPill.forUser(event.sender, roomId, client);
    await client.sendMessage(roomId, {
        body: `${mention.text}: starting build of PRs:
${prInfoText}`,
        msgtype: "m.notice",
    });

    const builds = prInfo.map(async info => {
        const output = await runNixpkgsReview(info.number, config.githubToken);
        const url = await postOnTermbin(output);
        await client.sendMessage(roomId, {
            body: `${mention.text}: build of PR ${info.number} done: ${url}`,
            msgtype: "m.notice"
        });
    });
}


async function runNixpkgsReview(pr: number, githubToken: string) {
    const nprBinPath = await findBinariesInPath("nixpkgs-review");

    const child = spawn(`${nprBinPath[0]} pr --no-shell --sandbox --post-result ${pr}`,
        {
            env: { GITHUB_TOKEN: githubToken },
            cwd: config.nixpkgsRepo.localPath,
            shell: true
        }
    );

    let combined = "";
    child.stdout.on("data", data => {
        LogService.debug("PrCommand", `child ${child.pid} stdout: ${data}`);
        combined += data.toString();
    });

    child.stderr.on("data", data => {
        LogService.debug("PrCommand", `child ${child.pid} stderr: ${data}`);
        combined += data.toString();
    });

    await (() => new Promise((resolve) => {
        child.on("exit", code => {
            combined += `process exited with code ${code}`;
            resolve(code);
        })
    }))()

    return combined;
}

async function findBinariesInPath(name: string) {
    const results = (await Promise.all(process.env.PATH.split(":").map(async dir => {
        try {
            await fs.access(join(dir, name));
        } catch {
            return;
        }
        return join(dir, name);
    }))).filter(bin => !(bin === undefined || bin === null));
    if (results.length == 0) throw new Error(`${name} not found in PATH`);
    return results;
}

function postOnTermbin(content: string): Promise<URL> {
    return new Promise((resolve, reject) => {
        const [host, port] = config.termbinAddress.split(":");
        const sock = connectTcp({ host, port: parseInt(port, 10), timeout: 10000 }, () => {
            sock.write(content);
            sock.on("data", data => {
                resolve(new URL(data.toString()));
                sock.end();
            });
        });
        sock.on("error", reject);

        // this will be ignored if we already resolve()'d with the URL
        sock.on("close", reject);
    });
}
