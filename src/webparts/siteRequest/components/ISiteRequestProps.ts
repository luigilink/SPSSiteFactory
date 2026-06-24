import type { SPHttpClient } from '@microsoft/sp-http';

export interface ISiteRequestProps {
  spHttpClient: SPHttpClient;
  userDisplayName: string;
  webAbsoluteUrl: string;
}
