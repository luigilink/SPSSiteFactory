import * as React from 'react';
import * as ReactDom from 'react-dom';
import { Version } from '@microsoft/sp-core-library';
import {
  type IPropertyPaneConfiguration
} from '@microsoft/sp-property-pane';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';
import { IReadonlyTheme } from '@microsoft/sp-component-base';

import * as strings from 'SiteRequestWebPartStrings';
import SiteRequest from './components/SiteRequest';
import { ISiteRequestProps } from './components/ISiteRequestProps';
import { PeopleSearchService } from './services/PeopleSearchService';
import { SiteRequestService } from './services/SiteRequestService';

export interface ISiteRequestWebPartProps {
}

export default class SiteRequestWebPart extends BaseClientSideWebPart<ISiteRequestWebPartProps> {

  private _isDarkTheme: boolean = false;
  private _environmentMessage: string = '';
  private _peopleSearchService!: PeopleSearchService;
  private _siteRequestService!: SiteRequestService;

  public render(): void {
    const element: React.ReactElement<ISiteRequestProps> = React.createElement(
      SiteRequest,
      {
        peopleSearchService: this._peopleSearchService,
        requestedByLoginName: this.context.pageContext.user.loginName,
        siteRequestService: this._siteRequestService,
        userDisplayName: this.context.pageContext.user.displayName,
        webAbsoluteUrl: this.context.pageContext.web.absoluteUrl,
      }
    );

    ReactDom.render(element, this.domElement);
  }

  protected onInit(): Promise<void> {
    this._peopleSearchService = new PeopleSearchService(
      this.context.spHttpClient,
      this.context.pageContext.web.absoluteUrl
    );
    this._siteRequestService = new SiteRequestService(
      this.context.spHttpClient,
      this.context.pageContext.web.absoluteUrl
    );

    return this._getEnvironmentMessage().then(message => {
      this._environmentMessage = message;
    });
  }



  private _getEnvironmentMessage(): Promise<string> {
    if (!!this.context.sdks.microsoftTeams) { // running in Teams, office.com or Outlook
      return this.context.sdks.microsoftTeams.teamsJs.app.getContext()
        .then(context => {
          let environmentMessage: string = '';
          switch (context.app.host.name) {
            case 'Office': // running in Office
              environmentMessage = this.context.isServedFromLocalhost ? strings.AppLocalEnvironmentOffice : strings.AppOfficeEnvironment;
              break;
            case 'Outlook': // running in Outlook
              environmentMessage = this.context.isServedFromLocalhost ? strings.AppLocalEnvironmentOutlook : strings.AppOutlookEnvironment;
              break;
            case 'Teams': // running in Teams
            case 'TeamsModern':
              environmentMessage = this.context.isServedFromLocalhost ? strings.AppLocalEnvironmentTeams : strings.AppTeamsTabEnvironment;
              break;
            default:
              environmentMessage = strings.UnknownEnvironment;
          }

          return environmentMessage;
        });
    }

    return Promise.resolve(this.context.isServedFromLocalhost ? strings.AppLocalEnvironmentSharePoint : strings.AppSharePointEnvironment);
  }

  protected onThemeChanged(currentTheme: IReadonlyTheme | undefined): void {
    if (!currentTheme) {
      return;
    }

    this._isDarkTheme = !!currentTheme.isInverted;
    const {
      semanticColors
    } = currentTheme;

    if (semanticColors) {
      this.domElement.style.setProperty('--bodyText', semanticColors.bodyText || null);
      this.domElement.style.setProperty('--link', semanticColors.link || null);
      this.domElement.style.setProperty('--linkHovered', semanticColors.linkHovered || null);
    }

  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: {
            description: strings.PropertyPaneDescription
          },
          groups: [
            {
              groupName: strings.BasicGroupName,
              groupFields: []
            }
          ]
        }
      ]
    };
  }
}
