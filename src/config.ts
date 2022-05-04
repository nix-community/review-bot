import * as config from "config";

interface IConfig {
    homeserverUrl: string;
    accessToken: string;
    autoJoin: boolean;
    dataPath: string;
    encryption: boolean;
    nixpkgsRepo: { owner: string, repo: string; localPath: string; };
    termbinAddress: string;
    githubToken: string;
}

export default <IConfig>config;
