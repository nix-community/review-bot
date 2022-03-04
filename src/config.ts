import * as config from "config";

interface IConfig {
    homeserverUrl: string;
    accessToken: string;
    autoJoin: boolean;
    dataPath: string;
    encryption: boolean;
    nixpkgsRepo: { owner: string, repo: string; localPath: string; };
    termbinAddress: string;
    githubTokenFile: string;
}

export default <IConfig>config;
