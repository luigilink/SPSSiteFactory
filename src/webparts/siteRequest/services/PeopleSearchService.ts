import { IPersonaProps } from '@fluentui/react';
import { SPHttpClient, SPHttpClientResponse } from '@microsoft/sp-http';
import { IPeoplePickerUser } from '../models/IPeoplePickerUser';

interface IClientPeoplePickerEntityData {
  Department?: string;
  Email?: string;
}

interface IClientPeoplePickerEntity {
  Description?: string;
  DisplayText?: string;
  EntityData?: IClientPeoplePickerEntityData;
  Key?: string;
}

interface IClientPeoplePickerResponse {
  value: string;
}

export class PeopleSearchService {
  public constructor(
    private readonly spHttpClient: SPHttpClient,
    private readonly webAbsoluteUrl: string
  ) {}

  public async searchUsers(filterText: string, selectedItems?: IPersonaProps[]): Promise<IPersonaProps[]> {
    const query: string = filterText.trim();

    if (query.length < 2) {
      return [];
    }

    const response: SPHttpClientResponse = await this.spHttpClient.post(
      `${this.webAbsoluteUrl}/_api/SP.UI.ApplicationPages.ClientPeoplePickerWebServiceInterface.clientPeoplePickerSearchUser`,
      SPHttpClient.configurations.v1,
      {
        body: JSON.stringify({
          queryParams: {
            AllowEmailAddresses: true,
            AllowMultipleEntities: false,
            AllUrlZones: false,
            MaximumEntitySuggestions: 5,
            PrincipalSource: 15,
            PrincipalType: 1,
            QueryString: query
          }
        }),
        headers: {
          Accept: 'application/json;odata=nometadata',
          'Content-Type': 'application/json;odata=nometadata'
        }
      }
    );

    if (!response.ok) {
      throw new Error(`People search failed with HTTP ${response.status}: ${response.statusText}`);
    }

    const searchResponse: IClientPeoplePickerResponse = await response.json();
    const entities: IClientPeoplePickerEntity[] = JSON.parse(searchResponse.value) as IClientPeoplePickerEntity[];
    const selectedIds: Set<string | undefined> = new Set((selectedItems || []).map(item => item.id));

    return entities
      .map(this.mapPeoplePickerEntityToPersona)
      .filter(persona => !selectedIds.has(persona.id));
  }

  public static getUserFromPersona(persona: IPersonaProps): IPeoplePickerUser {
    return {
      displayName: persona.text || '',
      email: persona.secondaryText || '',
      id: persona.id || '',
      loginName: persona.id || persona.secondaryText || ''
    };
  }

  private mapPeoplePickerEntityToPersona(entity: IClientPeoplePickerEntity): IPersonaProps {
    return {
      id: entity.Key,
      secondaryText: entity.EntityData?.Email || entity.Description,
      tertiaryText: entity.EntityData?.Department,
      text: entity.DisplayText || entity.EntityData?.Email || entity.Key
    };
  }
}
