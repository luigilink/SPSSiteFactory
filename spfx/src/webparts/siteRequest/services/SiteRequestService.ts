import { SPHttpClient, SPHttpClientResponse } from '@microsoft/sp-http';
import { siteRequestListTitle, siteRequestStatus } from '../constants/siteRequestConstants';
import {
  ISiteRequestOwner,
  ISiteRequestPayload,
  ISiteRequestSubmissionResult
} from '../models/ISiteRequestPayload';

interface IEnsureUserResponse {
  Id: number;
}

interface ICreateSiteRequestResponse {
  Id: number;
}

export class SiteRequestService {
  public constructor(
    private readonly spHttpClient: SPHttpClient,
    private readonly webAbsoluteUrl: string
  ) {}

  public async submitRequest(payload: ISiteRequestPayload): Promise<ISiteRequestSubmissionResult> {
    const [primaryOwnerId, secondaryOwnerId, requestedById]: [number, number, number] = await Promise.all([
      this.ensureUser(payload.primaryOwner),
      this.ensureUser(payload.secondaryOwner),
      this.ensureUser({
        displayName: '',
        email: '',
        loginName: payload.requestedByLoginName
      })
    ]);

    const response: SPHttpClientResponse = await this.spHttpClient.post(
      `${this.webAbsoluteUrl}/_api/web/lists/getByTitle('${this.escapeODataString(siteRequestListTitle)}')/items`,
      SPHttpClient.configurations.v1,
      {
        body: JSON.stringify({
          BusinessJustification: payload.businessJustification,
          PrimaryOwnerId: primaryOwnerId,
          RequestedById: requestedById,
          RequestedDate: new Date().toISOString(),
          SecondaryOwnerId: secondaryOwnerId,
          SiteAlias: payload.siteAlias,
          SiteName: payload.siteName,
          SiteType: payload.siteType,
          Status: siteRequestStatus.submitted,
          Title: payload.siteName
        }),
        headers: {
          Accept: 'application/json;odata=nometadata',
          'Content-Type': 'application/json;odata=nometadata'
        }
      }
    );

    if (!response.ok) {
      const errorBody: string = await response.text();
      throw new Error(`Site request submission failed with HTTP ${response.status}: ${errorBody || response.statusText}`);
    }

    const item: ICreateSiteRequestResponse = await response.json();

    return {
      itemId: item.Id
    };
  }

  private async ensureUser(owner: ISiteRequestOwner): Promise<number> {
    const response: SPHttpClientResponse = await this.spHttpClient.post(
      `${this.webAbsoluteUrl}/_api/web/ensureuser`,
      SPHttpClient.configurations.v1,
      {
        body: JSON.stringify({
          logonName: owner.loginName
        }),
        headers: {
          Accept: 'application/json;odata=nometadata',
          'Content-Type': 'application/json;odata=nometadata'
        }
      }
    );

    if (!response.ok) {
      const errorBody: string = await response.text();
      throw new Error(`User resolution failed for ${owner.loginName} with HTTP ${response.status}: ${errorBody || response.statusText}`);
    }

    const ensuredUser: IEnsureUserResponse = await response.json();

    return ensuredUser.Id;
  }

  private escapeODataString(value: string): string {
    return value.replace(/'/g, "''");
  }
}
