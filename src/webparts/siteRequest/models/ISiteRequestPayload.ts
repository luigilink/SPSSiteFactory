export interface ISiteRequestOwner {
  displayName: string;
  email: string;
  loginName: string;
}

export interface ISiteRequestPayload {
  businessJustification: string;
  primaryOwner: ISiteRequestOwner;
  requestedByLoginName: string;
  secondaryOwner: ISiteRequestOwner;
  siteAlias: string;
  siteName: string;
  siteType: string;
}

export interface ISiteRequestSubmissionResult {
  itemId: number;
}
