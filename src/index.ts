import {
    AutojoinRoomsMixin, LogLevel,
    LogService,
    MatrixClient,
    PantalaimonClient,
    RichConsoleLogger, SimpleFsStorageProvider
} from "matrix-bot-sdk";
import * as path from "path";
import config from "./config";
import CommandHandler from "./commands/handler";

LogService.setLogger(new RichConsoleLogger());
LogService.setLevel(LogLevel.DEBUG);

(async function () {
    const storage = new SimpleFsStorageProvider(path.join(config.dataPath, "bot.json"));
    const client = new MatrixClient(config.homeserverUrl, config.accessToken, storage);

    if (config.autoJoin) {
        AutojoinRoomsMixin.setupOnClient(client);
    }

    const commands = new CommandHandler(client);
    await commands.start();

    LogService.info("index", "Starting sync...");
    await client.start(); // This blocks until the bot is killed
})();
