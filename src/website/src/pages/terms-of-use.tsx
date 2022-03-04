import React from 'react';
import { Flex, Header, Layout } from '../components';
import { styled } from '../stitches.config';

const Timestamp = styled('p', {});

const Title = styled('h1', {
  margin: '$2 0',
});

const InfoBox = styled('p', {
  marginTop: '$1',
  marginBottom: '$3',
  padding: '$3',
  backgroundColor: '$slate3',
  borderRadius: '$1'
});

const Paragraph = styled('p', {});

const SectionTitle = styled('h2', {
  margin: '$2 0',
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

export function TermsOfUse() {
  return (
    <Layout>
      <Header />
      <Flex css={{flexDirection:"column", alignItems: "center"}}>
        <Flex css={{flexDirection:"column", maxWidth: 1024, padding: "$2"}}>
          <Timestamp>Page last updated: March 4, 2022</Timestamp>
          <Title>Terms of Use</Title>
          <InfoBox>You are prohibited from accessing, using or otherwise receiving any benefits of the Interface or our other offerings and services if you fail to satisfy the eligibility requirements set forth in Section 1 hereof or if you otherwise breach or violate any of the terms and conditions set forth herein. The eligibility requirements mandate, among other things, that you not reside in or be a citizen of a Restricted Territory (as defined below), that you are not a Sanctioned List Person (as defined below) and that you do not intend to transact in or with any Restricted Territory or Sanctions List Person If you fail to meet the eligibility requirements set forth i n Section 1 or are otherwise not in strict compliance with these Terms, then you must not attempt to access or use the Interface or any of our other offerings or services. Use of a virtual private network (e.g., a VPN) or other means by restricted persons to access or use the Interface is prohibited and may subject you to legal liability for fraudulent use of the Interface.</InfoBox>
          <Paragraph>Welcome to <a href="https://stakedicp.com" target="_blank" rel="nofollow noopener">https://stakedicp.com</a>, a website-hosted user interface (the “<strong>Interface</strong>”) made available by Aegir Finance Ltd. (“we”, “our”, or “us”). The Interface provides access to a decentralized protocol, known as “StakedICP,” which allows users to stake ether and receive in return stICP tokens in a number corresponding to the staked ether (the “<strong>Protocol</strong>”).<br /><br />These Terms of Use and any terms and conditions incorporated herein by reference (collectively, the “<strong>Terms</strong>”) govern your access to and use of the Interface. You must read the Terms carefully. By accessing, browsing or otherwise using the Interface, or by acknowledging agreement to the Terms on the Interface, you agree that you have read, understood and accepted all of the Terms and our Privacy Policy (the “<strong>Privacy Policy</strong>”), which is incorporated by reference into the Terms. THE TERMS CONTAIN IMPORTANT INFORMATION, INCLUDING A BINDING ARBITRATION PROVISION AND A CLASS ACTION WAIVER, BOTH OF WHICH IMPACT YOUR RIGHTS AS TO HOW DISPUTES ARE RESOLVED.<br /><br />We may change, amend, or revise the Terms from time to time and at any time, in our sole discretion. When we make changes, we will make the updated Terms available on the Interface and update the “Last Updated” date at the beginning of the Terms accordingly. Please check the Terms periodically for changes. Any changes to the Terms will be applicable as of the date that they are made, and your continued access to or use of the Interface after the Terms have been updated will constitute your binding acceptance of such updates. If you do not agree to the revised Terms, then you should not continue to access or use the Interface.</Paragraph>
          <SectionTitle>1. Eligibility</SectionTitle>
          <Paragraph>In order to use the Interface, you must satisfy the following eligibility requirements. You hereby represent and warrant, to and for the benefit of us and each of our officers, directors, supervisors, shareholders, members, investors, employees, agents, service providers and affiliates that you satisfy all of the eligibility requirements as of each date that you make any use or receive any benefits of the Interface.</Paragraph>
          <OrderedList>
            <OrderedListItem>
              <span>1.1</span>
              <p>you are of legal age in the jurisdiction in which you reside and you have legal capacity to enter into the Terms and be bound by them;</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>1.2</span>
              <p>if you accept the Terms on behalf of a legal entity, you must have the legal authority to accept the Terms on that entity’s behalf, in which case “you” as used herein (except as used in this paragraph) will mean that entity;</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>1.3</span>
              <p>(i) you are not a resident, citizen, national or agent of, or an entity organized, incorporated or doing business in, Belarus, Burundi, Crimea and Sevastopol, Cuba, Democratic Republic of Congo, Iran, Iraq, Libya, North Korea, Somalia, Sudan, Syria, Venezuela, Zimbabwe or any other country to which the United States, the United Kingdom, the Cayman Islands, the European Union or any of its member states or the United Nations or any of its member states (collectively, the “Major Jurisdictions”) embargoes goods or imposes similar sanctions (such embargoed or sanctioned territories, collectively, the “<strong>Restricted Territories</strong>”); (ii) you are not, and do not directly or indirectly own or control, and have not received any assets from, any blockchain address that is, listed on any sanctions list or equivalent maintained by any of the Major (such sanctions-listed persons, collectively, “<strong>Sanctions Lists Persons</strong>”); and (iii) you do not intend to transact in or with any Restricted Territories or Sanctions List Persons; and</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>1.4</span>
              <p>you are not a Restricted Person; and</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>1.5</span>
              <p>your use of the Interface is not prohibited by and does not otherwise violate or facilitate the violation of any applicable laws or regulations, or contribute to or facilitate any illegal activity.</p>
            </OrderedListItem>
          </OrderedList>
          <SectionTitle>2. Access to the Interface</SectionTitle>
          <Paragraph>We reserve the right to disable access to the Interface at any time, with or without cause or good reason. Our grounds for terminating access to the Interface may include, but are not limited to, any breach of the Terms, including without limitation, if we, in our sole discretion, believe that you, at any time, fail to satisfy the eligibility requirements set forth in the Terms. Further, we reserve the right to limit or restrict access to the Interface by any person or entity, or within any geographic area or legal jurisdiction, at any time and in our sole discretion. We will not be liable to you for any losses or damages you may suffer as a result of or in connection with the Interface being inaccessible to you at any time or for any reason.</Paragraph>
          <SectionTitle>3. Proprietary Rights</SectionTitle>
          <OrderedList>
            <OrderedListItem>
              <span>3.1</span>
              <p>We own all intellectual property and other rights in the Interface and its contents, including, but not limited to, software, text, images, trademarks, service marks, copyrights, patents, and designs. Unless expressly authorized by us, you may not copy, modify, adapt, rent, license, sell, publish, distribute, or otherwise permit any third party to access or use the Interface or any of its contents. Accessing or using the Interface does not constitute a grant to you of any proprietary intellectual property or other rights in the Interface or its contents.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>3.2</span>
              <p>You will retain ownership of all intellectual property and other rights in any information and materials you submit through the Interface. However, by uploading such information or materials, you grant us a worldwide, royalty-free, irrevocable license to use, copy, distribute, publish and send this data in any manner in accordance with applicable laws and regulations.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>3.3</span>
              <p>You may choose to submit comments, bug reports, ideas or other feedback about the Interface, including, without limitation, about how to improve the Interface (collectively, “Feedback”). By submitting any Feedback, you agree that we are free to use such Feedback at our discretion and without additional compensation to you, and to disclose such Feedback to third parties (whether on a non-confidential basis, or otherwise). If necessary under applicable law, then you hereby grant us a perpetual, irrevocable, non-exclusive, transferable, worldwide license under all rights necessary for us to incorporate and use your Feedback for any purpose.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>3.4</span>
              <p>If (i) you satisfy all of the eligibility requirements set forth in the Terms, and (ii) your access to and use of the Interface complies with the Terms, you hereby are granted a single, personal, limited license to access and use the Interface. This license is non-exclusive, non-transferable, and freely revocable by us at any time without notice or cause in our sole discretion. Use of the Interface for any purpose not expressly permitted by the Terms is strictly prohibited. Unlike the Interface, the Protocol is comprised entirely of open-source software running on the public Ethereum blockchain and is not our proprietary property.</p>
            </OrderedListItem>
          </OrderedList>
          <SectionTitle>4. Prohibited Activity</SectionTitle>
          <Paragraph>You agree not to engage in, or attempt to engage in, any of the following categories of prohibited activity in relation to your access or use of the Interface:</Paragraph>
          <OrderedList>
            <OrderedListItem>
              <span>4.1</span>
              <p>Activity that breaches the Terms;</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.2</span>
              <p>Activity that infringes on or violates any copyright, trademark, service mark, patent, right of publicity, right of privacy, or other proprietary or intellectual property rights under the law.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.3</span>
              <p>Activity that seeks to interfere with or compromise the integrity, security, or proper functioning of any computer, server, network, personal device, or other information technology system, including, but not limited to, the deployment of viruses and denial of service attacks.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.4</span>
              <p>Activity that seeks to defraud us or any other person or entity, including, but not limited to, providing any false, inaccurate, or misleading information in order to unlawfully obtain the property of another.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.5</span>
              <p>Activity that violates any applicable law, rule, or regulation concerning the integrity of trading markets, including, but not limited to, the manipulative tactics commonly known as spoofing and wash trading.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.6</span>
              <p>Activity that violates any applicable law, rule, or regulation of any Major Jurisdiction.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.7</span>
              <p>Activity that disguises or interferes in any way with the IP address of the computer you are using to access or use the Interface or that otherwise prevents us from correctly identifying the IP address of the computer you are using to access the Interface.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.8</span>
              <p>Activity that transmits, exchanges, or is otherwise supported by the direct or indirect proceeds of criminal or fraudulent activity.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>4.9</span>
              <p>Activity that contributes to or facilitates any of the foregoing activities.</p>
            </OrderedListItem>
          </OrderedList>
          <SectionTitle>5. No Professional Advice or Fiduciary Duties</SectionTitle>
          <OrderedList>
            <OrderedListItem>
              <span>5.1</span>
              <p>All information provided in connection with your access and use of the Interface is for informational purposes only and should not be construed as professional advice. You should not take, or refrain from taking, any action based on any information contained in the Interface or any other information that we make available at any time, including, without limitation, blog posts, articles, links to third-party content, news feeds, tutorials, tweets and videos. Before you make any financial, legal, or other decisions involving the Interface, you should seek independent professional advice from an individual who is licensed and qualified in the area for which such advice would be appropriate.</p>
            </OrderedListItem>
            <OrderedListItem>
              <span>5.2</span>
              <p>The Terms are not intended to, and do not, create or impose any fiduciary duties on us. To the fullest extent permitted by law, you acknowledge and agree that we owe no fiduciary duties or liabilities to you or any other party, and that to the extent any such duties or liabilities may exist at law or in equity, those duties and liabilities are hereby irrevocably disclaimed, waived, and eliminated. You further agree that the only duties and obligations that we owe you are those set forth expressly in the Terms.</p>
            </OrderedListItem>
          </OrderedList>
          <SectionTitle>6. No Warranties</SectionTitle>
          <Paragraph>The Interface is provided on an “AS IS” and “AS AVAILABLE” basis. To the fullest extent permitted by law, we disclaim any representations and warranties of any kind, whether express, implied, or statutory, including, but not limited to, the warranties of merchantability and fitness for a particular purpose. You acknowledge and agree that your access and use of the Interface is at your own risk. We do not represent or warrant that access to the Interface will be continuous, uninterrupted, timely, or secure; that the information contained in the Interface will be accurate, reliable, complete, or current; or that the Interface will be free from errors, defects, viruses, or other harmful elements. No advice, information, or statement that we make should be treated as creating any warranty concerning the Interface. We do not endorse, guarantee, or assume responsibility for any advertisements, offers, or statements made by third parties concerning the Interface.</Paragraph>
          <SectionTitle>7. Compliance Obligations</SectionTitle>
          <Paragraph>The Interface may not be available or appropriate for use in all jurisdictions. By accessing or using the Interface, you agree that you are solely and entirely responsible for compliance with all laws and regulations that may apply to you. You further agree that we have no obligation to inform you of any potential liabilities or violations of law or regulation that may arise in connection with your access and use of the Interface and that we are not liable in any respect for any failure by you to comply with any applicable laws or regulations.</Paragraph>
          <SectionTitle>8. Assumption of Risk</SectionTitle>
          <Paragraph>By accessing and using the Interface, you represent that you understand (a) the Interface facilitates access to the Protocol, the use of which has many inherent risks, and (b) the cryptographic and blockchain-based systems have inherent risks to which you are exposed when using the Interface. You further represent that you have a working knowledge of the usage and intricacies of blockchain-based digital assets, including, without limitation, ERC-20 token standard available on the Ethereum blockchain. You further understand that the markets for these blockchain-based digital assets are highly volatile due to factors that include, but are not limited to, adoption, speculation, technology, security, and regulation. You acknowledge that the cost and speed of transacting with blockchain-based systems, such as Ethereum, are variable and may increase or decrease, respectively, drastically at any time. You hereby acknowledge and agree that we are not responsible for any of these variables or risks associated with the Protocol and cannot be held liable for any resulting losses that you experience while accessing or using the Interface. Accordingly, you understand and agree to assume full responsibility for all of the risks of accessing and using the Interface to interact with the Protocol.</Paragraph>
          <SectionTitle>9. Third-Party Resources and Promotions</SectionTitle>
          <Paragraph>The Interface may contain references or links to third-party resources, including, but not limited to, information, materials, products, or services, that we do not own or control. In addition, third parties may offer promotions related to your access and use of the Interface. We do not endorse or assume any responsibility for any such resources or promotions. If you access any such resources or participate in any such promotions, you do so at your own risk, and you understand that the Terms do not apply to your dealings or relationships with any third parties. You expressly relieve us of any and all liability arising from your use of any such resources or participation in any such promotions.</Paragraph>
          <SectionTitle>10. Release of Claims</SectionTitle>
          <Paragraph>You expressly agree that you assume all risks in connection with your access to and use of the Interface. Additionally, you expressly waive and release us from any and all liability, claims, causes of action, or damages arising from or in any way relating to your access to and use of the Interface.</Paragraph>
          <SectionTitle>11. Indemnity</SectionTitle>
          <Paragraph>You agree to hold harmless, release, defend, and indemnify us and our officers, directors, employees, contractors, agents, affiliates, and subsidiaries from and against all claims, damages, obligations, losses, liabilities, costs, and expenses arising from: (a) your access to and use of the Interface; (b) your violation of the Terms, the rights of any third party, or any other applicable law, rule, or regulation; and (c) any other party’s access to and use of the Interface with your assistance or using any device or account that you own or control.</Paragraph>
          <SectionTitle>12. Limitation of Liability</SectionTitle>
          <Paragraph>Under no circumstances shall we or any of our officers, directors, employees, contractors, agents, affiliates, or subsidiaries be liable to you for any indirect, punitive, incidental, special, consequential, or exemplary damages, including (but not limited to) damages for loss of profits, goodwill, use, data, or other intangible property, arising out of or relating to any access to or use of the Interface, nor will we be responsible for any damage, loss, or injury resulting from hacking, tampering, or other unauthorized access to or use of the Interface, or from any access to or use of any information obtained by any unauthorized access to or use of the Interface. We assume no liability or responsibility for any: (a) errors, mistakes, or inaccuracies of content; (b) personal injury or property damage, of any nature whatsoever, resulting from any access to or use of the Interface; (c) unauthorized access to or use of any secure server or database in our control, or the use of any information or data stored therein; (d) interruption or cessation of function related to the Interface; (e) bugs, viruses, trojan horses, or the like that may be transmitted to or through the Interface; (f) errors or omissions in, or loss or damage incurred as a result of, the use of any content made available through the Interface; and (g) the defamatory, offensive, or illegal conduct of any third party. Under no circumstances shall we or any of our officers, directors, employees, contractors, agents, affiliates, or subsidiaries be liable to you for any claims, proceedings, liabilities, obligations, damages, losses, or costs in an amount exceeding the greater of (i) the amount you paid to us in exchange for access to and use of the Interface, or (ii) $100.00. This limitation of liability applies regardless of whether the alleged liability is based on contract, tort, negligence, strict liability, or any other basis, and even if we have been advised of the possibility of such liability. Some jurisdictions do not allow the exclusion of certain warranties or the limitation or exclusion of certain liabilities and damages. Accordingly, some of the disclaimers and limitations set forth in the Terms may not apply to you. This limitation of liability shall apply to the fullest extent permitted by law.</Paragraph>
          <SectionTitle>13. Dispute Resolution</SectionTitle>
          <Paragraph>We will use our best efforts to resolve any potential disputes through informal, good faith negotiations. If a potential dispute arises, you must first contact us by sending an email to <a href="mailto:info@stakedicp.com" target="_blank" rel="nofollow noopener">info@stakedicp.com</a> so that we can attempt to resolve it without resorting to formal dispute resolution. If we are not able to reach an informal resolution within sixty days of your email, then you and we both agree to resolve the potential dispute according to the process set forth below. Any claim or controversy arising out of or relating to the Interface, the Terms, or any other acts or omissions for which you may contend that we are liable, including (but not limited to) any claim or controversy as to arbitrability (each, a “Dispute”), shall be finally and exclusively settled by arbitration administered by the London Court of International Arbitration under the LCIA Arbitration Rules in force at the time of the filing for arbitration of any Dispute. You understand that you are required to resolve all Disputes by binding arbitration. The arbitration shall be held on a confidential basis before a single arbitrator and shall be conducted in English. Unless we agree otherwise, the arbitrator may not consolidate your claims with those of any other party. Any judgment on the award rendered by the arbitrator may be entered in any court of the Cayman Islands or other court of competent jurisdiction consented to in writing by us. You further agree that the Interface shall be deemed to be based solely in the Cayman Islands and that, although the Interface may be available in other jurisdictions, its availability does not give rise to general or specific personal jurisdiction in any forum outside the Cayman Islands.</Paragraph>
          <SectionTitle>14. Class Action and Jury Trial Waiver</SectionTitle>
          <Paragraph>You must bring any and all Disputes against us in your individual capacity and not as a plaintiff in or member of any purported class action, collective action, private attorney general action, or other representative proceeding. This provision applies to class arbitration. You and we both agree to waive the right to demand a trial by jury.</Paragraph>
          <SectionTitle>15. Governing Law</SectionTitle>
          <Paragraph>You agree that the laws of the Cayman Islands, without regard to principles of conflict of laws, govern the Terms and any Dispute between you and us.</Paragraph>
          <SectionTitle>16. Entire Agreement</SectionTitle>
          <Paragraph>The Terms, including the Privacy Policy, constitute the entire agreement between you and us with respect to the subject matter hereof, including the Interface. The Terms, including the Privacy Policy, supersede any and all prior or contemporaneous written and oral agreements, communications and other understandings relating to the subject matter of the Terms.</Paragraph>
          <SectionTitle>17. Privacy Policy</SectionTitle>
          <Paragraph>The Privacy Policy describes the ways we collect, use, store and disclose your personal information. You agree to the collection, use, storage, and disclosure of your data in accordance with the Privacy Policy.</Paragraph>
        </Flex>
      </Flex>
    </Layout>
  );
}
