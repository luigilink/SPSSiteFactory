import { PeopleSearchService } from '../services/PeopleSearchService';
import { ProvisioningService } from '../services/ProvisioningService';
import { SiteRequestService } from '../services/SiteRequestService';

export interface ISiteRequestProps {
  peopleSearchService: PeopleSearchService;
  provisioningService: ProvisioningService;
  requestedByLoginName: string;
  siteRequestService: SiteRequestService;
  userDisplayName: string;
  webAbsoluteUrl: string;
}
