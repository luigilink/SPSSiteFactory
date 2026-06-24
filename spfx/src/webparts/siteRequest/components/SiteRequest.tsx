import * as React from 'react';
import {
  DefaultButton,
  IBasePickerSuggestionsProps,
  Icon,
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
  aliasManuallyEdited: boolean;
  siteType: string;
  businessJustification: string;
  primaryOwner: string;
  secondaryOwner: string;
  submittedItemId?: number;
  submitState: 'idle' | 'submitting' | 'submitted' | 'failed';
}

interface ISiteTypeChoice {
  key: string;
  title: string;
  icon: string;
  description: string;
  bullets: string[];
}

const siteTypeChoices: ISiteTypeChoice[] = [
  {
    key: 'TeamSite',
    title: 'Team site',
    icon: 'Group',
    description: 'Create a private space to collaborate with your team.',
    bullets: [
      'Track and stay updated on project status',
      'Share resources and co-author content',
      'Owners and members publish content'
    ]
  },
  {
    key: 'CommunicationSite',
    title: 'Communication site',
    icon: 'Megaphone',
    description: 'Share information that engages a broad audience.',
    bullets: [
      'Create a portal or subject-focused site',
      'Engage many viewers',
      'Few authors, many visitors'
    ]
  }
];

const initialFormState: ISiteRequestFormState = {
  errorMessage: '',
  siteName: '',
  siteAlias: '',
  aliasManuallyEdited: false,
  siteType: '',
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

const computeSitePreviewUrl = (baseUrl: string, alias: string): string => {
  if (!alias) {
    return '';
  }

  try {
    return `${new URL(baseUrl).origin}/sites/${alias}`;
  } catch {
    return `/sites/${alias}`;
  }
};

const slugifySiteAlias = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .replace(/-{2,}/g, '-')
    .replace(/^-+|-+$/g, '');

const sanitizeAliasInput = (value: string): string =>
  value
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '');

const SiteRequest: React.FC<ISiteRequestProps> = ({
  peopleSearchService,
  requestedByLoginName,
  siteRequestService,
  userDisplayName,
  webAbsoluteUrl
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

  const handleSiteNameChange = (value: string): void => {
    setFormState(previousState => ({
      ...previousState,
      siteName: value,
      siteAlias: previousState.aliasManuallyEdited ? previousState.siteAlias : slugifySiteAlias(value),
      errorMessage: '',
      submitState: 'idle',
      submittedItemId: undefined
    }));
  };

  const handleSiteAliasChange = (value: string): void => {
    setFormState(previousState => ({
      ...previousState,
      siteAlias: sanitizeAliasInput(value),
      aliasManuallyEdited: true,
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
    !!formState.siteType &&
    !!formState.primaryOwner.trim() &&
    !!formState.secondaryOwner.trim() &&
    !siteAliasError &&
    !ownerError;

  const isSubmitting: boolean = formState.submitState === 'submitting';

  const sitePreviewUrl: string = computeSitePreviewUrl(webAbsoluteUrl, formState.siteAlias);

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

  const renderSiteTypeCard = (choice: ISiteTypeChoice): React.ReactElement => {
    const isSelected: boolean = formState.siteType === choice.key;
    const selectChoice = (): void => updateField('siteType', choice.key);

    return (
      <div
        key={choice.key}
        role="radio"
        aria-checked={isSelected}
        aria-label={choice.title}
        tabIndex={0}
        className={`${styles.typeCard} ${isSelected ? styles.typeCardSelected : ''}`}
        onClick={selectChoice}
        onKeyDown={event => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            selectChoice();
          }
        }}
      >
        <div className={styles.typeCardHeader}>
          <Icon iconName={choice.icon} className={styles.typeCardIcon} />
          {isSelected && <Icon iconName="CompletedSolid" className={styles.typeCardCheck} />}
        </div>
        <Text className={styles.typeCardTitle}>{choice.title}</Text>
        <Text className={styles.typeCardDesc}>{choice.description}</Text>
        <ul className={styles.typeCardBullets}>
          {choice.bullets.map(bullet => (
            <li key={bullet}>{bullet}</li>
          ))}
        </ul>
      </div>
    );
  };

  const summaryStatus: { label: string; className: string } = (() => {
    switch (formState.submitState) {
      case 'submitting':
        return { label: 'Submitting…', className: styles.statusPillProgress };
      case 'submitted':
        return { label: 'Submitted', className: styles.statusPill };
      default:
        return { label: 'Will be submitted', className: styles.statusPillNeutral };
    }
  })();

  return (
    <section className={styles.siteRequest}>
      <Stack tokens={{ childrenGap: 24 }}>
        <div className={styles.headerBand}>
          <Icon iconName="SharePointLogo" className={styles.headerIcon} />
          <Stack tokens={{ childrenGap: 4 }}>
            <Text variant="xxLarge" as="h1" className={styles.headerTitle}>Request a SharePoint Online site</Text>
            <Text variant="medium" className={styles.headerSubtitle}>
              Submit a governed site creation request. Valid requests are tracked in the {siteRequestListTitle} list and provisioned automatically.
            </Text>
            <span className={styles.requesterChip}>
              <Icon iconName="Contact" />
              Requester: {userDisplayName}
            </span>
          </Stack>
        </div>

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
            <Stack className={styles.section} tokens={{ childrenGap: 12 }}>
              <div className={styles.sectionHeader}>
                <span className={styles.sectionIndex}>1</span>
                <Text className={styles.sectionTitle}>Site information</Text>
              </div>
              <Stack horizontal wrap tokens={{ childrenGap: 16 }} className={styles.fieldRow}>
                <Stack.Item grow className={styles.fieldItem}>
                  <TextField
                    label="Site name"
                    required
                    value={formState.siteName}
                    placeholder="Project Alpha"
                    onChange={(_, value) => handleSiteNameChange(value || '')}
                  />
                </Stack.Item>
                <Stack.Item grow className={styles.fieldItem}>
                  <TextField
                    label="Site alias"
                    required
                    value={formState.siteAlias}
                    placeholder="project-alpha"
                    description="Auto-filled from the site name. Edit to override."
                    errorMessage={siteAliasError}
                    onChange={(_, value) => handleSiteAliasChange(value || '')}
                  />
                </Stack.Item>
              </Stack>
              {sitePreviewUrl && (
                <div className={styles.urlPreview}>
                  <Icon iconName="Link" />
                  <span className={styles.urlPreviewLabel}>Site URL preview:</span>
                  <span className={styles.urlPreviewValue}>{sitePreviewUrl}</span>
                </div>
              )}
              <div>
                <Label required>Site type</Label>
                <div role="radiogroup" aria-label="Site type" className={styles.typeGrid}>
                  {siteTypeChoices.map(renderSiteTypeCard)}
                </div>
              </div>
            </Stack>

            <Stack className={styles.section} tokens={{ childrenGap: 12 }}>
              <div className={styles.sectionHeader}>
                <span className={styles.sectionIndex}>2</span>
                <Text className={styles.sectionTitle}>Ownership &amp; justification</Text>
              </div>
              <Stack horizontal wrap tokens={{ childrenGap: 16 }} className={styles.fieldRow}>
                <Stack.Item grow className={styles.fieldItem}>
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
                </Stack.Item>
                <Stack.Item grow className={styles.fieldItem}>
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
                </Stack.Item>
              </Stack>
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

            <Stack horizontal className={styles.actions} tokens={{ childrenGap: 12 }}>
              <PrimaryButton
                text={isSubmitting ? 'Submitting...' : 'Submit request'}
                disabled={!isFormValid || isSubmitting}
                onClick={submitRequest}
              />
              <DefaultButton text="Reset" disabled={isSubmitting} onClick={resetForm} />
            </Stack>
          </Stack>
        </div>

        {isFormValid ? (
          <div className={styles.summaryCard}>
            <div className={styles.summaryHeader}>
              <Icon iconName="ClipboardList" />
              <Text variant="xLarge" as="h2" className={styles.summaryTitle}>Request summary</Text>
            </div>
            <dl className={styles.summaryList}>
              <dt>Site name</dt>
              <dd>{formState.siteName}</dd>
              <dt>Site alias</dt>
              <dd>{formState.siteAlias}</dd>
              <dt>Site type</dt>
              <dd>{siteTypeChoices.find(choice => choice.key === formState.siteType)?.title}</dd>
              <dt>Primary owner</dt>
              <dd>{formState.primaryOwner}</dd>
              <dt>Secondary owner</dt>
              <dd>{formState.secondaryOwner}</dd>
              <dt>Initial status</dt>
              <dd><span className={summaryStatus.className}>{summaryStatus.label}</span></dd>
            </dl>
            {formState.submitState === 'submitted' && (
              <MessageBar messageBarType={MessageBarType.success}>
                Site request submitted successfully. Request item ID: {formState.submittedItemId}.
              </MessageBar>
            )}
          </div>
        ) : (
          <div className={styles.summaryPlaceholder}>
            <Icon iconName="ClipboardList" className={styles.summaryPlaceholderIcon} />
            <Text>Complete the form to see the request summary.</Text>
          </div>
        )}
      </Stack>
    </section>
  );
};

export default SiteRequest;
