import { AadHttpClient, AadHttpClientFactory, HttpClientResponse } from '@microsoft/sp-http';
import { IProvisioningTriggerResult } from '../models/ISiteRequestPayload';

export interface IProvisioningServiceConfig {
  // Entra ID application id URI (or client id) exposing the SubmitSiteRequest function,
  // e.g. api://<client-id>. Empty disables the call (the list write still happens).
  functionResourceUri: string;
  // Absolute URL of the SubmitSiteRequest HTTP endpoint.
  functionUrl: string;
}

interface ISubmitFunctionResponse {
  status?: string;
  itemId?: number;
}

export class ProvisioningService {
  public constructor(
    private readonly aadHttpClientFactory: AadHttpClientFactory,
    private readonly config: IProvisioningServiceConfig
  ) {}

  public get isConfigured(): boolean {
    return (
      !!this.config &&
      !!this.config.functionResourceUri &&
      !!this.config.functionUrl
    );
  }

  /**
   * Notify the provisioning Function that a new request item is ready.
   *
   * This is intentionally best-effort: the request item already exists in SharePoint,
   * so a transient Function failure must not surface as a submission error. The backend
   * (or a later polling job) can still pick the item up. Failures are reported back so
   * the UI can show an informational message without blocking the user.
   */
  public async triggerProvisioning(
    requestSiteUrl: string,
    itemId: number
  ): Promise<IProvisioningTriggerResult> {
    if (!this.isConfigured) {
      return { triggered: false, status: 'skipped', message: 'Provisioning endpoint is not configured.' };
    }

    try {
      const client: AadHttpClient = await this.aadHttpClientFactory.getClient(this.config.functionResourceUri);

      const response: HttpClientResponse = await client.post(
        this.config.functionUrl,
        AadHttpClient.configurations.v1,
        {
          headers: {
            Accept: 'application/json',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            requestSiteUrl,
            itemId
          })
        }
      );

      if (!response.ok) {
        const errorBody: string = await response.text();
        return {
          triggered: false,
          status: 'failed',
          message: `Provisioning trigger returned HTTP ${response.status}: ${errorBody || response.statusText}`
        };
      }

      const result: ISubmitFunctionResponse = await response.json();

      return {
        triggered: true,
        status: 'queued',
        message: result.status
      };
    } catch (error) {
      return {
        triggered: false,
        status: 'failed',
        message: error instanceof Error ? error.message : 'Provisioning trigger failed.'
      };
    }
  }
}
