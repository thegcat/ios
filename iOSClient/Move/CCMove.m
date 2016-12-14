//
//  CCMove.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
//  Copyright (c) 2014 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCMove.h"

#ifndef SHARE_IN
#import "AppDelegate.h"
#endif

@interface CCMove ()
{    
    NSString *activeAccount;
    NSString *activePassword;
    NSString *activeUrl;
    NSString *activeUser;
    NSString *directoryUser;
    NSString *typeCloud;
    NSString *activeUID;
    NSString *activeAccessToken;
    
    CCHud *_hud;
}
@end

@implementation CCMove

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    
    if (recordAccount) {
        
        activeAccount = recordAccount.account;
        activePassword = recordAccount.password;
        activeUrl = recordAccount.url;
        activeUser = recordAccount.user;
        directoryUser = [CCUtility getDirectoryActiveUser:activeUser activeUrl:activeUrl];
        typeCloud = recordAccount.typeCloud;
        activeUID = recordAccount.uid;
        activeAccessToken = recordAccount.token;
        
    } else {
        
        UIAlertController * alert= [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"_no_active_account_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
    _hud = [[CCHud alloc] initWithView:self.view];

    // TableView : at the end of rows nothing
    self.tableView.tableFooterView = [UIView new];

    [self.cancel setTitle:NSLocalizedString(@"_cancel_", nil)];

    if (![self.localServerUrl length]) {
        
        self.localServerUrl = [CCUtility getHomeServerUrlActiveUrl:activeUrl typeCloud:typeCloud];
        UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:image_brandNavigationController]];
        [self.navigationController.navigationBar.topItem setTitleView:image];
        self.title = @"Home";
        
    } else {
        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0,0, self.navigationItem.titleView.frame.size.width, 40)];
        label.text = self.passMetadata.fileNamePrint;
        
        if (self.passMetadata.cryptated) label.textColor = COLOR_ENCRYPTED;
        else label.textColor = self.tintColorTitle;
        
        label.backgroundColor =[UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        self.navigationItem.titleView=label;
    }
    
    // Toolbar Color
    self.navigationController.navigationBar.barTintColor = self.barTintColor;
    self.navigationController.navigationBar.tintColor = self.tintColor;
    
    self.navigationController.toolbar.barTintColor = self.barTintColor;
    self.navigationController.toolbar.tintColor = self.tintColor;
    
    // read folder
    [_hud visibleIndeterminateHud];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.serverUrl = self.localServerUrl;
    metadataNet.selector = selectorReadFolder;
    metadataNet.date = nil;
    
    [self addNetworkingQueue:metadataNet];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == alertView ==
#pragma --------------------------------------------------------------------------------------------

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        NSString *nome = [alertView textFieldAtIndex:0].text;
        if ([nome length]) {
            nome = [NSString stringWithFormat:@"%@/%@", self.localServerUrl, [CCUtility clearFile:nome]];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == IBAction ==
#pragma --------------------------------------------------------------------------------------------

- (IBAction)cancel:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)move:(UIBarButtonItem *)sender
{
    [_networkingOperationQueue cancelAllOperations];
    
    [self.delegate move:self.localServerUrl title:self.passMetadata.fileNamePrint selectedMetadatas:self.selectedMetadatas];
        
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == BKPasscodeViewController ==
#pragma --------------------------------------------------------------------------------------------

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    [self performSegueDirectoryWithControlPasscode:false];
}

- (void)passcodeViewController:(BKPasscodeViewController *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
        
        self.lockUntilDate = nil;
        self.failedAttempts = 0;
        aResultHandler(YES);
        
    } else {
        
        aResultHandler(NO);
    }
}

- (void)passcodeViewControllerDidFailAttempt:(BKPasscodeViewController *)aViewController
{
    self.failedAttempts++;
    
    if (self.failedAttempts > 5) {
        
        NSTimeInterval timeInterval = 60;
        
        if (self.failedAttempts > 6) {
            
            NSUInteger multiplier = self.failedAttempts - 6;
            
            timeInterval = (5 * 60) * multiplier;
            
            if (timeInterval > 3600 * 24) {
                timeInterval = 3600 * 24;
            }
        }
        
        self.lockUntilDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    }
}

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(BKPasscodeViewController *)aViewController
{
    return self.failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(BKPasscodeViewController *)aViewController
{
    return self.lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ======================= NetWorking ==================================
#pragma --------------------------------------------------------------------------------------------

- (void)dropboxFailure
{
    [_hud hideHud];
    
    UIAlertController * alert= [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_comm_error_dropbox_", nil) message:NSLocalizedString(@"_comm_error_dropbox_txt_", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* ok = [UIAlertAction actionWithTitle: NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [alert dismissViewControllerAnimated:YES completion:nil];
                                               }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addNetworkingQueue:(CCMetadataNet *)metadataNet
{
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([typeCloud isEqualToString:typeCloudOwnCloud] || [typeCloud isEqualToString:typeCloudNextcloud]) {
        
        OCnetworking *operation = [[OCnetworking alloc] initWithDelegate:self metadataNet:metadataNet withUser:activeUser withPassword:activePassword withUrl:activeUrl withTypeCloud:typeCloud oneByOne:YES activityIndicator:NO];
        
        _networkingOperationQueue.maxConcurrentOperationCount = maxConcurrentOperation;
        [_networkingOperationQueue addOperation:operation];
    }
    
#ifdef CC
    
    /*** DROPBOX ***/

    if ([typeCloud isEqualToString:typeCloudDropbox]) {
        
        DBnetworking *operation = [[DBnetworking alloc] initWithDelegate:self metadataNet:metadataNet withUser:activeUser withPassword:activePassword withUrl:activeUrl withActiveUID:activeUID withActiveAccessToken:activeAccessToken oneByOne:YES activityIndicator:NO];
        
        _networkingOperationQueue.maxConcurrentOperationCount = maxConcurrentOperation;
        [_networkingOperationQueue addOperation:operation];
    }
#endif
    
}

- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    if ([selector isEqualToString:selectorLoadPlist]) {

        CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, activeAccount] context:nil];

        [CCCoreData downloadFilePlist:metadata activeAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud directoryUser:directoryUser];
        
        [self.tableView reloadData];
    }
}

- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    self.move.enabled = NO;
}

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];

    self.move.enabled = NO;    
}

- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions rev:(NSString *)rev metadatas:(NSArray *)metadatas
{
    // remove all record
    [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((session == NULL) OR (session == ''))", activeAccount, metadataNet.directoryID]];
        
    for (CCMetadata *metadata in metadatas) {
        
        // do not insert crypto file
        if ([CCUtility isCryptoString:metadata.fileName]) continue;
        
        // plist + crypto = completed ?
        if ([CCUtility isCryptoPlistString:metadata.fileName] && metadata.directory == NO) {
            
            BOOL isCryptoComplete = NO;
            
            for (CCMetadata *completeMetadata in metadatas) {
                if ([completeMetadata.fileName isEqualToString:[CCUtility trasformedFileNamePlistInCrypto:metadata.fileName]]) isCryptoComplete = YES;
            }
            if (isCryptoComplete == NO) continue;
        }
        
        [CCCoreData addMetadata:metadata activeAccount:activeAccount activeUrl:activeUrl typeCloud:typeCloud context:nil];
        
        // if plist do not exists, download it !
        if ([CCUtility isCryptoPlistString:metadata.fileName] && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileName]] == NO) {
            
            // download only the directories
            for (CCMetadata *metadataDirectory in metadatas) {
                
                if (metadataDirectory.directory == YES && [metadataDirectory.fileName isEqualToString:metadata.fileNameData]) {
                    
                    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
                    
                    metadataNet.action = actionDownloadFile;
                    metadataNet.metadata = metadata;
                    metadataNet.downloadData = NO;
                    metadataNet.downloadPlist = YES;
                    metadataNet.selector = selectorLoadPlist;
                    metadataNet.serverUrl = _localServerUrl;
                    metadataNet.session = download_session_foreground;
                    metadataNet.taskStatus = taskStatusResume;
                    
                    [self addNetworkingQueue:metadataNet];
                }
            }
        }
    }
    
    [self.tableView reloadData];
    
    [_hud hideHud];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Table ==
#pragma --------------------------------------------------------------------------------------------

- (void)reloadTable
{
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:self.localServerUrl activeAccount:activeAccount];
    NSPredicate *predicate;
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (directory == 1) AND (cryptated == 0)", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (directory == 1)", activeAccount, directoryID];
    
    return [[CCCoreData getTableMetadataWithPredicate:predicate context:nil] count];    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSPredicate *predicate;
    
    static NSString *CellIdentifier = @"MyCustomCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:self.localServerUrl activeAccount:activeAccount];
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (directory == 1) AND (cryptated == 0)", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (directory == 1)", activeAccount, directoryID];

    CCMetadata *metadata = [CCCoreData getMetadataAtIndex:predicate fieldOrder:@"fileName" ascending:YES objectAtIndex:indexPath.row];
    
    // colors
    if (metadata.cryptated) {
        cell.textLabel.textColor = COLOR_ENCRYPTED;
    } else {
        cell.textLabel.textColor = COLOR_CLEAR;
    }
    
    cell.detailTextLabel.text = @"";
    cell.imageView.image = [UIImage imageNamed:metadata.iconName];
    cell.textLabel.text = metadata.fileNamePrint;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self performSegueDirectoryWithControlPasscode:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Navigation ==
#pragma --------------------------------------------------------------------------------------------

- (void)performSegueDirectoryWithControlPasscode:(BOOL)controlPasscode
{
    NSString *nomeDir;
    NSPredicate *predicate;

    NSIndexPath *index = [self.tableView indexPathForSelectedRow];
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:self.localServerUrl activeAccount:activeAccount];
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (directory == 1) AND (cryptated == 0)", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (directory == 1)", activeAccount, directoryID];
    
    CCMetadata *metadata = [CCCoreData getMetadataAtIndex:predicate fieldOrder:@"fileName" ascending:YES objectAtIndex:index.row];
    
    if (metadata.errorPasscode == NO) {
    
        // lockServerUrl
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:self.localServerUrl addServerUrl:metadata.fileNameData];
        
        // SE siamo in presenza di una directory bloccata E è attivo il block E la sessione PASSWORD Lock è senza data ALLORA chiediamo la password per procedere
        if ([CCCoreData isDirectoryLock:lockServerUrl activeAccount:activeAccount] && [[CCUtility getBlockCode] length] && controlPasscode) {
            
            CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
            viewController.delegate = self;
            //viewController.fromType = CCBKPasscodeFromLockDirectory;
            viewController.type = BKPasscodeViewControllerCheckPasscodeType;
            viewController.inputViewTitlePassword = YES;
            
            if ([CCUtility getSimplyBlockCode]) {
                
                viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
                viewController.passcodeInputView.maximumLength = 6;
                
            } else {
                
                viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
                viewController.passcodeInputView.maximumLength = 64;
            }
            
            BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:BKPasscodeKeychainServiceName];
            touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
            viewController.touchIDManager = touchIDManager;
            
            viewController.title = NSLocalizedString(@"_folder_blocked_", nil);
            viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
            viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
            
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            [self presentViewController:navController animated:YES completion:nil];
            
            return;
        }
        
        if (metadata.cryptated) nomeDir = [metadata.fileName substringToIndex:[metadata.fileName length]-6];
        else nomeDir = metadata.fileName;
    
        CCMove *viewController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMoveVC"];
    
        viewController.delegate = self.delegate;
        viewController.onlyClearDirectory = self.onlyClearDirectory;
        viewController.selectedMetadatas = self.selectedMetadatas;
        viewController.move.title = self.move.title;
        viewController.barTintColor = self.barTintColor;
        viewController.tintColor = self.tintColor;
        viewController.tintColorTitle = self.tintColorTitle;
        viewController.networkingOperationQueue = _networkingOperationQueue;

        viewController.passMetadata = metadata;
        viewController.localServerUrl = [CCUtility stringAppendServerUrl:self.localServerUrl addServerUrl:nomeDir];
    
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

@end