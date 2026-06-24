import { PeopleSearchService } from '../services/PeopleSearchService';
import { SiteRequestService } from '../services/SiteRequestService';

export interface ISiteRequestProps {
  peopleSearchService: PeopleSearchService;
  requestedByLoginName: string;
  siteRequestService: SiteRequestService;
  userDisplayName: string;
  webAbsoluteUrl: string;
}
