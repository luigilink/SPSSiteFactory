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
import { siteRequestListTitle } from '../constants/siteRequestConstants';
import { ISiteRequestOwner, ISiteRequestSubmissionResult } from '../models/ISiteRequestPayload';
import { PeopleSearchService } from '../services/PeopleSearchService';
import styles from './SiteRequest.module.scss';
import type { ISiteRequestProps } from './ISiteRequestProps';

interface ISiteRequestFormState {
  errorMessage: string;
  siteName: string;
  siteAlias: string;
  siteType: string;
  businessJustification: string;
  primaryOwner: string;
  secondaryOwner: string;
  submittedItemId?: number;
  submitState: 'idle' | 'submitting' | 'submitted' | 'failed';
}

const siteTypeOptions: IDropdownOption[] = [
  { key: 'TeamSite', text: 'Team site' },
  { key: 'CommunicationSite', text: 'Communication site' }
];

const initialFormState: ISiteRequestFormState = {
  errorMessage: '',
  siteName: '',
  siteAlias: '',
  siteType: 'TeamSite',
  businessJustification: '',
  primaryOwner: '',
  secondaryOwner: '',
  submitState: 'idle'
};

const siteAliasPattern: RegExp = /^[a-z0-9-]+$/;

const getSelectedPersonValue = (items: IPersonaProps[]): string => {
  const selectedPerson: IPersonaProps | undefined = items[0];

  return selectedPerson ? selectedPerson.secondaryText || selectedPerson.text || '' : '';
};

const getOwnerFromPersona = (persona: IPersonaProps): ISiteRequestOwner => {
  const user = PeopleSearchService.getUserFromPersona(persona);

  return {
    displayName: user.displayName,
    email: user.email,
    loginName: user.loginName
  };
};

const pickerSuggestionsProps: IBasePickerSuggestionsProps = {
  noResultsFoundText: 'No users found',
  loadingText: 'Searching users...',
  suggestionsHeaderText: 'Suggested users'
};

const SiteRequest: React.FC<ISiteRequestProps> = ({
  peopleSearchService,
  requestedByLoginName,
  siteRequestService,
  userDisplayName
}) => {
  const [formState, setFormState] = React.useState<ISiteRequestFormState>(initialFormState);
  const [primaryOwnerPersonas, setPrimaryOwnerPersonas] = React.useState<IPersonaProps[]>([]);
  const [secondaryOwnerPersonas, setSecondaryOwnerPersonas] = React.useState<IPersonaProps[]>([]);

  const updateField = (fieldName: keyof ISiteRequestFormState, value: string): void => {
    setFormState(previousState => ({
      ...previousState,
      [fieldName]: value,
      errorMessage: '',
      submitState: 'idle',
      submittedItemId: undefined
    }));
  };

  const resetForm = (): void => {
    setPrimaryOwnerPersonas([]);
    setSecondaryOwnerPersonas([]);
    setFormState(initialFormState);
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

  const isSubmitting: boolean = formState.submitState === 'submitting';

  const resolveUserSuggestions = async (
    filterText: string,
    selectedItems?: IPersonaProps[]
  ): Promise<IPersonaProps[]> => {
    return peopleSearchService.searchUsers(filterText, selectedItems);
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

  const submitRequest = async (): Promise<void> => {
    const primaryOwner: IPersonaProps | undefined = primaryOwnerPersonas[0];
    const secondaryOwner: IPersonaProps | undefined = secondaryOwnerPersonas[0];

    if (!isFormValid || !primaryOwner || !secondaryOwner) {
      return;
    }

    setFormState(previousState => ({
      ...previousState,
      errorMessage: '',
      submitState: 'submitting',
      submittedItemId: undefined
    }));

    try {
      const result: ISiteRequestSubmissionResult = await siteRequestService.submitRequest({
        businessJustification: formState.businessJustification.trim(),
        primaryOwner: getOwnerFromPersona(primaryOwner),
        requestedByLoginName,
        secondaryOwner: getOwnerFromPersona(secondaryOwner),
        siteAlias: formState.siteAlias.trim(),
        siteName: formState.siteName.trim(),
        siteType: formState.siteType
      });

      setFormState(previousState => ({
        ...previousState,
        submitState: 'submitted',
        submittedItemId: result.itemId
      }));
    } catch (error) {
      setFormState(previousState => ({
        ...previousState,
        errorMessage: error instanceof Error ? error.message : 'The site request could not be submitted.',
        submitState: 'failed',
        submittedItemId: undefined
      }));
    }
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
          V1 submission mode: valid requests are created in the {siteRequestListTitle} SharePoint list.
        </MessageBar>

        {formState.errorMessage && (
          <MessageBar messageBarType={MessageBarType.error}>
            {formState.errorMessage}
          </MessageBar>
        )}

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
              <PrimaryButton
                text={isSubmitting ? 'Submitting...' : 'Submit request'}
                disabled={!isFormValid || isSubmitting}
                onClick={submitRequest}
              />
              <DefaultButton text="Reset" disabled={isSubmitting} onClick={resetForm} />
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
            <dd>Submitted</dd>
          </dl>
          {formState.submitState === 'submitted' && (
            <MessageBar messageBarType={MessageBarType.success}>
              Site request submitted successfully. Request item ID: {formState.submittedItemId}.
            </MessageBar>
          )}
        </div>
      </Stack>
    </section>
  );
};

export default SiteRequest;
