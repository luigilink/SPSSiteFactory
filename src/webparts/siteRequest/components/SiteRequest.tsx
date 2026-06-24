import * as React from 'react';
import {
  DefaultButton,
  Dropdown,
  IBasePickerSuggestionsProps,
  IDropdownOption,
  IPersonaProps,
  Label,
  MessageBar,
  MessageBarType,
  NormalPeoplePicker,
  PrimaryButton,
  Stack,
  Text,
  TextField
} from '@fluentui/react';
import { SPHttpClient, SPHttpClientResponse } from '@microsoft/sp-http';
import styles from './SiteRequest.module.scss';
import type { ISiteRequestProps } from './ISiteRequestProps';

interface ISiteRequestFormState {
  siteName: string;
  siteAlias: string;
  siteType: string;
  businessJustification: string;
  primaryOwner: string;
  secondaryOwner: string;
  submittedLocally: boolean;
}

interface IClientPeoplePickerEntityData {
  Department?: string;
  Email?: string;
  Title?: string;
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

const siteTypeOptions: IDropdownOption[] = [
  { key: 'TeamSite', text: 'Team site' },
  { key: 'CommunicationSite', text: 'Communication site' }
];

const initialFormState: ISiteRequestFormState = {
  siteName: '',
  siteAlias: '',
  siteType: 'TeamSite',
  businessJustification: '',
  primaryOwner: '',
  secondaryOwner: '',
  submittedLocally: false
};

const siteAliasPattern: RegExp = /^[a-z0-9-]+$/;

const getSelectedPersonValue = (items: IPersonaProps[]): string => {
  const selectedPerson: IPersonaProps | undefined = items[0];

  return selectedPerson ? selectedPerson.secondaryText || selectedPerson.text || '' : '';
};

const pickerSuggestionsProps: IBasePickerSuggestionsProps = {
  noResultsFoundText: 'No users found',
  loadingText: 'Searching users...',
  suggestionsHeaderText: 'Suggested users'
};

const mapPeoplePickerEntityToPersona = (entity: IClientPeoplePickerEntity): IPersonaProps => ({
  id: entity.Key,
  secondaryText: entity.EntityData?.Email || entity.Description,
  tertiaryText: entity.EntityData?.Department,
  text: entity.DisplayText || entity.EntityData?.Email || entity.Key
});

const SiteRequest: React.FC<ISiteRequestProps> = ({ spHttpClient, userDisplayName, webAbsoluteUrl }) => {
  const [formState, setFormState] = React.useState<ISiteRequestFormState>(initialFormState);
  const [primaryOwnerPersonas, setPrimaryOwnerPersonas] = React.useState<IPersonaProps[]>([]);
  const [secondaryOwnerPersonas, setSecondaryOwnerPersonas] = React.useState<IPersonaProps[]>([]);

  const updateField = (fieldName: keyof ISiteRequestFormState, value: string): void => {
    setFormState(previousState => ({
      ...previousState,
      [fieldName]: value,
      submittedLocally: false
    }));
  };

  const resetForm = (): void => {
    setPrimaryOwnerPersonas([]);
    setSecondaryOwnerPersonas([]);
    setFormState(initialFormState);
  };

  const submitLocalPreview = (): void => {
    setFormState(previousState => ({
      ...previousState,
      submittedLocally: true
    }));
  };

  const siteAliasError: string | undefined =
    formState.siteAlias && !siteAliasPattern.test(formState.siteAlias)
      ? 'Use lowercase letters, numbers, and hyphens only.'
      : undefined;

  const ownerError: string | undefined =
    formState.primaryOwner &&
    formState.secondaryOwner &&
    formState.primaryOwner.trim().toLowerCase() === formState.secondaryOwner.trim().toLowerCase()
      ? 'Primary and secondary owners should be different.'
      : undefined;

  const isFormValid: boolean =
    !!formState.siteName.trim() &&
    !!formState.siteAlias.trim() &&
    !!formState.businessJustification.trim() &&
    !!formState.primaryOwner.trim() &&
    !!formState.secondaryOwner.trim() &&
    !siteAliasError &&
    !ownerError;

  const resolveUserSuggestions = async (
    filterText: string,
    selectedItems?: IPersonaProps[]
  ): Promise<IPersonaProps[]> => {
    const query: string = filterText.trim();

    if (query.length < 2) {
      return [];
    }

    const response: SPHttpClientResponse = await spHttpClient.post(
      `${webAbsoluteUrl}/_api/SP.UI.ApplicationPages.ClientPeoplePickerWebServiceInterface.clientPeoplePickerSearchUser`,
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
      .map(mapPeoplePickerEntityToPersona)
      .filter(persona => !selectedIds.has(persona.id));
  };

  const updatePrimaryOwner = (items?: IPersonaProps[]): void => {
    const selectedItems: IPersonaProps[] = items || [];

    setPrimaryOwnerPersonas(selectedItems);
    updateField('primaryOwner', getSelectedPersonValue(selectedItems));
  };

  const updateSecondaryOwner = (items?: IPersonaProps[]): void => {
    const selectedItems: IPersonaProps[] = items || [];

    setSecondaryOwnerPersonas(selectedItems);
    updateField('secondaryOwner', getSelectedPersonValue(selectedItems));
  };

  return (
    <section className={styles.siteRequest}>
      <Stack tokens={{ childrenGap: 24 }}>
        <Stack className={styles.header} tokens={{ childrenGap: 8 }}>
          <Text variant="xxLarge" as="h1">Request a SharePoint Online site</Text>
          <Text variant="medium">
            Submit a governed site creation request. This first version prepares the request payload before connecting it to the
            SiteFactoryRequests SharePoint list.
          </Text>
          <Text variant="small" className={styles.requester}>Requester: {userDisplayName}</Text>
        </Stack>

        <MessageBar messageBarType={MessageBarType.info}>
          V1 preview mode: the form validates request metadata locally. SharePoint list submission will be added in the next step.
        </MessageBar>

        <div className={styles.formCard}>
          <Stack tokens={{ childrenGap: 20 }}>
            <Stack tokens={{ childrenGap: 12 }}>
              <Label>Site information</Label>
              <TextField
                label="Site name"
                required
                value={formState.siteName}
                placeholder="Project Alpha"
                onChange={(_, value) => updateField('siteName', value || '')}
              />
              <TextField
                label="Site alias"
                required
                value={formState.siteAlias}
                placeholder="project-alpha"
                description="Used to build the final SharePoint site URL."
                errorMessage={siteAliasError}
                onChange={(_, value) => updateField('siteAlias', (value || '').toLowerCase())}
              />
              <Dropdown
                label="Site type"
                selectedKey={formState.siteType}
                options={siteTypeOptions}
                onChange={(_, option) => updateField('siteType', option ? option.key.toString() : 'TeamSite')}
              />
            </Stack>

            <Stack tokens={{ childrenGap: 12 }}>
              <Label>Ownership and justification</Label>
              <div>
                <Label required>Primary owner</Label>
                <NormalPeoplePicker
                  inputProps={{ placeholder: 'Start typing a name or email' }}
                  itemLimit={1}
                  onChange={updatePrimaryOwner}
                  onResolveSuggestions={resolveUserSuggestions}
                  pickerSuggestionsProps={pickerSuggestionsProps}
                  resolveDelay={300}
                  selectedItems={primaryOwnerPersonas}
                />
              </div>
              <div>
                <Label required>Secondary owner</Label>
                <NormalPeoplePicker
                  inputProps={{ placeholder: 'Start typing a name or email' }}
                  itemLimit={1}
                  onChange={updateSecondaryOwner}
                  onResolveSuggestions={resolveUserSuggestions}
                  pickerSuggestionsProps={pickerSuggestionsProps}
                  resolveDelay={300}
                  selectedItems={secondaryOwnerPersonas}
                />
                {ownerError && <Text className={styles.errorText}>{ownerError}</Text>}
              </div>
              <TextField
                label="Business justification"
                required
                multiline
                rows={4}
                value={formState.businessJustification}
                placeholder="Explain why this site is needed and how it will be used."
                onChange={(_, value) => updateField('businessJustification', value || '')}
              />
            </Stack>

            <Stack horizontal tokens={{ childrenGap: 12 }}>
              <PrimaryButton text="Preview request" disabled={!isFormValid} onClick={submitLocalPreview} />
              <DefaultButton text="Reset" onClick={resetForm} />
            </Stack>
          </Stack>
        </div>

        <div className={styles.summaryCard}>
          <Text variant="xLarge" as="h2">Request summary</Text>
          <dl className={styles.summaryList}>
            <dt>Site name</dt>
            <dd>{formState.siteName || '-'}</dd>
            <dt>Site alias</dt>
            <dd>{formState.siteAlias || '-'}</dd>
            <dt>Site type</dt>
            <dd>{siteTypeOptions.find(option => option.key === formState.siteType)?.text || '-'}</dd>
            <dt>Primary owner</dt>
            <dd>{formState.primaryOwner || '-'}</dd>
            <dt>Secondary owner</dt>
            <dd>{formState.secondaryOwner || '-'}</dd>
            <dt>Initial status</dt>
            <dd>Draft</dd>
          </dl>
          {formState.submittedLocally && (
            <MessageBar messageBarType={MessageBarType.success}>
              The request payload is valid and ready for the SharePoint list integration.
            </MessageBar>
          )}
        </div>
      </Stack>
    </section>
  );
};

export default SiteRequest;
