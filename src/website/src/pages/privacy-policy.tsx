import React from 'react';
import { Flex, Header, Layout } from '../components';
import { styled } from '../stitches.config';

const Timestamp = styled('p', {});

const Title = styled('h1', {
  margin: '$2 0',
});

const Paragraph = styled('p', {});

const SectionTitle = styled('h2', {
  margin: '$2 0',
});

const TableWrapper = styled('div', {
  margin: '$2 0',
  table: {
    textAlign: 'left',
    borderSpacing: '$1',
    borderCollapse: 'separate',
    borderRadius: '$1',
    backgroundColor: '$slate3',
    backgroundColor: '$slate3',
  },
  td: {
    padding: '$2',
    verticalAlign: 'top',
    border: '2px solid $slate1',
  },
  th: {
    padding: '$2',
    verticalAlign: 'top',
    border: '2px solid $slate1',
  }
});

const OrderedList = styled('div', {});

const OrderedListItem = styled('div', {
  display: 'flex',
  flexDirection: 'row',
  margin: '$2',
  '& > span': {
    marginRight: '$2',
  }
});

const UnorderedList = styled('ul', {
  listStylePosition: 'inside',
  li: {
    margin: '$2',
  },
});

export function PrivacyPolicy() {
  return (
    <Layout>
      <Header />
      <Flex css={{flexDirection:"column", alignItems: "center"}}>
        <Flex css={{flexDirection:"column", maxWidth: 1024, padding: "$2"}}>
          <Timestamp>Page last updated: March 4, 2022</Timestamp>
          <Title>Privacy Policy</Title>
          <SectionTitle>Introduction</SectionTitle>
          <Paragraph>This Privacy Notice (the <strong>“Privacy Notice”</strong>) explains how Aegir Finance Ltd. handles the personal data of individuals – the<strong>“Data Subjects”</strong> or the <strong>“Data Subject”</strong>, or <strong>“you”</strong>, <strong>“your”</strong>, in connection with accessing and using the website and any services available at <a href="https://stakedicp.com" target="_blank" rel="nofollow noopener">https://stakedicp.com</a> (together referred to as the <strong>“Services”</strong>).<br /><br />Aegir Finance Ltd. located at: Address: Genesis Building, 5th Floor, Genesis Close, PO Box 446, Cayman Islands, KY1 1106 (the <strong>“Company”</strong> or<strong>“we”</strong>, <strong>“our”</strong>, <strong>“us”</strong>) is the controller for your personal data within the scope of this Privacy Notice. The Company decides “why” and “how” your personal data is processed in connection with the Services.<br /><br />If you are interested in how we use cookies and you can change your cookies choice, please go to section “Cookies and Automatically Collected Data”</Paragraph>
          <SectionTitle>Categories of Personal Data Collected, Purposes of and Bases for the Processing</SectionTitle>
          <Paragraph>When providing the Services, the Company may process certain personal data for the following purposes:</Paragraph>
          <TableWrapper>
            <table>
              <thead>
                <tr>
                  <th>Purpose of processing</th>
                  <th>Personal data</th>
                  <th>Legal ground (basis)</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Communicating with you regarding your inquiries, questions or support tickets</td>
                  <td>Email address, subject of inquiry and its content, attachments and any other information you voluntarily provide to us</td>
                  <td>Our legitimate interests / contractual obligations</td>
                </tr>
                <tr>
                  <td>Sending email newsletters</td>
                  <td>Email address</td>
                  <td>Your consent</td>
                </tr>
                <tr>
                  <td>Provides access to users of the website to a decentralized protocol, known as “Lido”</td>
                  <td>Wallet addresses, transaction and balance information</td>
                  <td>Our contractual obligations (terms of use)</td>
                </tr>
                <tr>
                  <td>Analyzing our website visitors’ actions to improve our Services</td>
                  <td>See section “Cookies and Automatically Collected Data”</td>
                  <td>Your consent</td>
                </tr>
              </tbody>
            </table>
          </TableWrapper>
          <Paragraph>We collect your personal data directly from you or from other parties whom you have authorized such collection. We do not process special categories of personal data about you unless you voluntarily provide such data to us. <br /><br />If you would like to learn more about the definitions used throughout this document such as the “legal grounds”, “legitimate interests” or “, please visit the Information Commissioner’s Office’s <a href="https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/lawful-basis-for-processing/" target="_blank" rel="nofollow noopener">website</a>.</Paragraph>
          <SectionTitle>Cookies and Automatically Collected Data</SectionTitle>
          <Paragraph>As you navigate through and interact with our website and the Services, we may ask your consent to use cookies, which are small files placed on the hard drive of your computer or mobile device, and web beacons, which are small electronic files located on pages of the website, to collect certain information about your equipment, browsing actions, and patterns.<br /><br />The data automatically collected from cookies and web beacons may include information from your web browser (such as browser type and browser language) and details of your visits to our website, including traffic data, location data and logs, page views, length of visit and website navigation paths as well as information about your device and internet connection, including your IP address and how you interact with the Services. We collect this data in order to help us improve our website and the Services.<br /><br />The information we collect automatically may also include statistical and performance information arising from your use of our Services and website. This type of data will only be used by us in an aggregated and anonymized manner.<br /><br />You can disable/delete the cookies set by our website - please find the appropriate instructions by following these links on how to implement the deletion in different browsers:</Paragraph>
          <UnorderedList>
            <li>For <strong>Google Chrome browser</strong> please refer to this <a href="https://support.google.com/accounts/answer/32050?co=GENIE.Platform%3DDesktop&amp;hl=en" target="_blank" rel="nofollow noopener">instructions</a></li>
            <li>For <strong>Firefox browser</strong> please look up <a href="https://support.mozilla.org/en-US/kb/clear-cookies-and-site-data-firefox" target="_blank" rel="nofollow noopener">here</a></li>
            <li>For <strong>Safari browser</strong> please <a href="https://support.apple.com/guide/safari/manage-cookies-and-website-data-sfri11471/mac" target="_blank" rel="nofollow noopener">visit</a></li>
            <li>For <strong>Internet Explorer browser</strong> please <a href="https://support.microsoft.com/en-us/help/17442/windows-internet-explorer-delete-manage-cookies" target="_blank" rel="nofollow noopener">refer to</a></li>
            </UnorderedList>
          <SectionTitle>Personal Data of Children</SectionTitle>
          <Paragraph>If you are a resident of the US and you are under the age of 13, please do not submit any personal data through the website. If you have reason to believe that a child under the age of 13 has provided personal data to us through the Services, please contact us, and we will endeavour to delete that information from our databases.<br /><br />If you are a resident of the European Economic Area and you are under the age of 16, please do not submit any personal data through the Services and the website. We do not collect or process Personal Information pertaining to a child, where a child under the GDPR is defined as an individual below the age of 16 years old.</Paragraph>
          <SectionTitle>Your Rights With Regard to the Personal Data Processing</SectionTitle>
          <Paragraph>In connection with the accessing, browsing of the website and using the Services, you shall be entitled to exercise certain rights laid down by the GDPR and outlined herein below, however exercise of some of those rights may not be possible in relation to the website and Services taking account of the Services’ nature, manner, form and other applicable circumstances. In some cases we may ask you to provide us additional evidence and information confirming your identity.<br /><br /><strong>Right to Access:</strong> you may request all personal data being processed about you by sending the right to access request to us.<br /><br /><strong>Right to Rectification:</strong> exercise of the given right directly depends on the data category concerned: if it concerns online identifiers obtained by the Company automatically, then their rectification isn’t possible, but such categories of personal data as email address may be rectified by sending us the respective request.<br /><br /><strong>Right to Erasure (Right to be Forgotten):</strong> you can send us the request to delete the personal data we are currently processing about you.<br /><br /><strong>Restriction of Processing:</strong> you shall be entitled to request restriction of processing from us if you contest the personal data accuracy or object to processing of the personal data for direct marketing.<br /><br /><strong>Objection to Processing:</strong> under certain circumstances you may exercise this right with respect to the personal data we process about you.<br /><br /><strong>Right to Data Portability:</strong> under certain circumstances you may exercise this right respect to the personal data we process about you. Please be aware the Services may not provide for the technical ability for us to to help you exercise this right.<br /><br /><strong>Consent Withdrawal Right:</strong> you shall be entitled to withdraw consent to the processing of the personal data to which you provided your consent. In particular, you can change your cookie choices by using our cookie consent tool built in the website. You can exercise your right to withdraw consent by unsubscribing from our email newsletter.<br /><br /><strong>Automated Decision-Making, Profiling:</strong> neither is being carried out by the Company as for now, your consent will be sought before carrying out any such activities.<br /><br />You shall have the right to lodge a complaint with a competent data protection supervisory authority.</Paragraph>
          <SectionTitle>Personal Data Storage Period or Criteria for Such Storage</SectionTitle>
          <Paragraph>Your Personal data will be stored till:</Paragraph>
          <UnorderedList>
            <li>they are necessary to render you the Services;</li>
            <li>your consent is no longer valid;</li>
            <li>your personal data have been deleted following your data deletion request;</li>
            <li>we have received the court order or a lawful authority’s request mandating to permanently delete all the personal data we have obtained about you; or</li>
            <li>In other circumstances prescribed by applicable laws. </li>
          </UnorderedList>
          <Paragraph>In any event, we will not store your personal data for periods longer than it is necessary for the purposes of the processing.</Paragraph>
          <SectionTitle>Personal Data Recipients and Transfer of Personal Data</SectionTitle>
          <Paragraph>For the purposes of rendering the Services to you and operating the website, the Company may share your personal data with certain categories of recipients and under circumstances mentioned below:</Paragraph>
          <OrderedList>
            <OrderedListItem>
              <span>1.</span>
              <p>providers, consultants, advisors, vendors and partners acting as data processors (meaning they process your personal data on our behalf and according to your instructions), which may supply hosting services, web analytics services, email marketing and automation services to run and operate the website, maintain, deliver and improve the Services. With all such parties we enter into data processing agreements required to be concluded by the applicable laws between controllers and processors to protect and secure the personal data by using appropriate technical and organizational measures;</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>2.</span>
              <p>only in strict compliance with the applicable provisions, the Company also may share the personal data with governmental authorities upon their decision, receipt of court orders mandating the Company to disclose the personal data. In any such case, the Company will strive to disclose only a portion of the personal data which is definitely required to be disclosed, while continuing to treat the rest of the data in confidence;</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>3.</span>
              <p>with any other third parties, if we have been explicitly requested to do so by you and as long as it doesn’t infringe the applicable laws.</p>
            </OrderedListItem>
          </OrderedList>
          <Paragraph>Transfers to third countries, shall be made subject to appropriate safeguards, namely standard contractual clauses adopted by a supervisory authority and approved by the Commission. Copy of the foregoing appropriate safeguards may be obtained by you upon a prior written request sent. We may instruct you on further steps to be taken with a purpose of obtaining such a copy, including your obligation to assume confidentiality commitments in connection with being disclosed the Company’s proprietary and personal information of third parties as well as terms of their relationships with the Company.<br /><br />Keep in mind that the use of services based on public blockchains intended to immutably record transactions across wide networks of computer systems. Many blockchains are open to forensic analysis which can lead to deanonymization and the unintentional revelation of personal data, in particular when blockchain data is combined with other data. Because blockchains are decentralized or third-party networks which are not controlled or operated by us, we are not able to erase, modify, or alter personal data from such networks.</Paragraph>
          <SectionTitle>Security of Processing</SectionTitle>
          <Paragraph>We take information security very seriously. We work hard to protect the personal data you give us from loss, misuse, or unauthorized access. We utilize a variety of safeguards to protect the personal data submitted to us, both during transmission and once it is received.</Paragraph>
          <SectionTitle>Contacts and Requests; Changes to the Privacy Notice</SectionTitle>
          <Paragraph>Please send all your requests and queries in connection with your rights and freedoms relating to the personal data protection and processing conducted by the Company as part of providing the website and rendering the Services to you to: <a href="mailto:info@stakedicp.com" target="_blank" rel="nofollow noopener">info@stakedicp.com</a>.<br /><br />Changes to the Privacy Notice will be displayed in the form of the updated document published on the website. We also can arrange the updates introduced to the Privacy Notice by archiving the previous versions of the document accessible in the electronic form on the website.</Paragraph>
        </Flex>
      </Flex>
    </Layout>
  );
}
