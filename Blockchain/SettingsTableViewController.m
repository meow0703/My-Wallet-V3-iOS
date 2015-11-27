//
//  SettingsTableViewController.m
//  Blockchain
//
//  Created by Kevin Wu on 7/13/15.
//  Copyright (c) 2015 Qkos Services Ltd. All rights reserved.
//

#import "SettingsTableViewController.h"
#import "SettingsSelectorTableViewController.h"
#import "SettingsAboutViewController.h"
#import "SettingsBitcoinUnitTableViewController.h"
#import "AppDelegate.h"

const int textFieldTagChangePasswordHint = 8;
const int textFieldTagVerifyMobileNumber = 7;
const int textFieldTagChangeMobileNumber = 6;
const int textFieldTagVerifyEmail = 5;

const int accountDetailsSection = 0;
const int accountDetailsIdentifier = 0;
const int accountDetailsMobileNumber = 1;
const int accountDetailsEmail = 2;

const int displaySection = 1;
const int displayLocalCurrency = 0;
const int displayBtcUnit = 1;

const int feesSection = 2;
const int feePerKb = 0;

const int securitySection = 3;
const int securityTwoStep = 0;
const int securityPasswordHint = 1;
const int securityPasswordChange = 2;
#ifdef TOUCH_ID_ENABLED
const int securityTouchID = 3;
#else
const int securityTouchID = -1;
#endif
const int aboutSection = 4;
const int aboutTermsOfService = 0;
const int aboutPrivacyPolicy = 1;

@interface SettingsTableViewController () <CurrencySelectorDelegate, BtcSelectorDelegate, UITextFieldDelegate>

@property (nonatomic, copy) NSDictionary *availableCurrenciesDictionary;
@property (nonatomic, copy) NSDictionary *accountInfoDictionary;
@property (nonatomic, copy) NSDictionary *allCurrencySymbolsDictionary;

@property (nonatomic, copy) NSString *enteredEmailString;
@property (nonatomic, copy) NSString *emailString;

@property (nonatomic, copy) NSString *enteredMobileNumberString;
@property (nonatomic, copy) NSString *mobileNumberString;

@property (nonatomic) UITextField *changeFeeTextField;
@property (nonatomic) float currentFeePerKb;

@property (nonatomic) BOOL isEnablingTwoStepSMS;

@end

@implementation SettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:USER_DEFAULTS_KEY_LOADED_SETTINGS];
    [self reload];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (app.wallet.isSyncingForCriticalProcess) {
        [app showBusyViewWithLoadingText:BC_STRING_LOADING_SYNCING_WALLET];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    SettingsNavigationController *navigationController = (SettingsNavigationController *)self.navigationController;
    navigationController.headerLabel.text = BC_STRING_SETTINGS;
    BOOL loadedSettings = [[[NSUserDefaults standardUserDefaults] objectForKey:USER_DEFAULTS_KEY_LOADED_SETTINGS] boolValue];
    if (!loadedSettings) {
        [self reload];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
#ifdef TOUCH_ID_ENABLED
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:securityTouchID inSection:securitySection];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
#endif
}

- (void)reload
{
    DLog(@"Reloading settings");
    
    self.isEnablingTwoStepSMS = NO;
    
    [self getAccountInfo];
    [self getAllCurrencySymbols];
}

- (void)getAllCurrencySymbols
{
    __block id notificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NOTIFICATION_KEY_GET_ALL_CURRENCY_SYMBOLS_SUCCESS object:nil queue:nil usingBlock:^(NSNotification *note) {
        DLog(@"SettingsTableViewController: gotCurrencySymbols");
        self.allCurrencySymbolsDictionary = note.userInfo;
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver name:NOTIFICATION_KEY_GET_ALL_CURRENCY_SYMBOLS_SUCCESS object:nil];
    }];
    
    [app.wallet getAllCurrencySymbols];
}

- (void)setAllCurrencySymbolsDictionary:(NSDictionary *)allCurrencySymbolsDictionary
{
    _allCurrencySymbolsDictionary = allCurrencySymbolsDictionary;
    
    [self reloadTableView];
}

- (void)getAccountInfo;
{
    __block id notificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NOTIFICATION_KEY_GET_ACCOUNT_INFO_SUCCESS object:nil queue:nil usingBlock:^(NSNotification *note) {
        DLog(@"SettingsTableViewController: gotAccountInfo");
        self.accountInfoDictionary = note.userInfo;
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:USER_DEFAULTS_KEY_LOADED_SETTINGS];
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver name:NOTIFICATION_KEY_GET_ACCOUNT_INFO_SUCCESS object:nil];
    }];
    
    [app.wallet getAccountInfo];
}

- (void)setAccountInfoDictionary:(NSDictionary *)accountInfoDictionary
{
    _accountInfoDictionary = accountInfoDictionary;
    
    if (_accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_CURRENCIES] != nil) {
        self.availableCurrenciesDictionary = _accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_CURRENCIES];
    }
    
    NSString *emailString = _accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_EMAIL];
    
    if (emailString != nil) {
        self.emailString = emailString;
    }
    
    NSString *mobileNumberString = _accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_SMS_NUMBER];

    if (mobileNumberString != nil) {
        self.mobileNumberString = mobileNumberString;
    }
    
    [self reloadTableView];
}

- (void)changeLocalCurrencySuccess
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_LOCAL_CURRENCY_SUCCESS object:nil];
    
    [self getHistory];
}

- (void)getHistory
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableView) name:NOTIFICATION_KEY_GET_HISTORY_SUCCESS object:nil];
    [app.wallet getHistory];
}

- (void)reloadTableView
{
    [self.tableView reloadData];
}

+ (UIFont *)fontForCell
{
    return [UIFont fontWithName:@"Helvetica Neue" size:15];
}

+ (UIFont *)fontForCellSubtitle
{
    return [UIFont fontWithName:@"Helvetica Neue" size:12];
}

- (CurrencySymbol *)getLocalSymbolFromLatestResponse
{
    return app.latestResponse.symbol_local;
}

- (CurrencySymbol *)getBtcSymbolFromLatestResponse
{
    return app.latestResponse.symbol_btc;
}

- (void)alertUserOfErrorLoadingSettings
{
    UIAlertController *alertForErrorLoading = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_ERROR_LOADING_TITLE message:BC_STRING_SETTINGS_ERROR_LOADING_MESSAGE preferredStyle:UIAlertControllerStyleAlert];
    [alertForErrorLoading addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertForErrorLoading animated:YES completion:nil];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:USER_DEFAULTS_KEY_LOADED_SETTINGS];
}

- (void)alertUserOfSuccess:(NSString *)successMessage
{
    UIAlertController *alertForSuccess = [UIAlertController alertControllerWithTitle:BC_STRING_SUCCESS message:successMessage preferredStyle:UIAlertControllerStyleAlert];
    [alertForSuccess addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertForSuccess animated:YES completion:nil];
}

- (void)alertUserOfError:(NSString *)errorMessage
{
    UIAlertController *alertForError = [UIAlertController alertControllerWithTitle:BC_STRING_ERROR message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
    [alertForError addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertForError animated:YES completion:nil];
}

#pragma mark - Change Fee per KB

- (float)getFeePerKb
{
    uint64_t unconvertedFee = [app.wallet getTransactionFee];
    float convertedFee = unconvertedFee / [[NSNumber numberWithInt:SATOSHI] floatValue];
    self.currentFeePerKb = convertedFee;
    return convertedFee;
}

- (NSString *)convertFloatToString:(float)floatNumber forDisplay:(BOOL)isForDisplay
{
    NSNumberFormatter *feePerKbFormatter = [[NSNumberFormatter alloc] init];
    feePerKbFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    feePerKbFormatter.maximumFractionDigits = 8;
    NSNumber *amountNumber = [NSNumber numberWithFloat:floatNumber];
    NSString *displayString = [feePerKbFormatter stringFromNumber:amountNumber];
    if (isForDisplay) {
        return displayString;
    } else {
        NSString *decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
        NSString *numbersWithDecimalSeparatorString = [[NSString alloc] initWithFormat:@"%@%@", NUMBER_KEYPAD_CHARACTER_SET_STRING, decimalSeparator];
        NSCharacterSet *characterSetFromString = [NSCharacterSet characterSetWithCharactersInString:displayString];
        NSCharacterSet *numbersAndDecimalCharacterSet = [NSCharacterSet characterSetWithCharactersInString:numbersWithDecimalSeparatorString];
        
        if (![numbersAndDecimalCharacterSet isSupersetOfSet:characterSetFromString]) {
            // Current keypad will not support this character set; return string with known decimal separators "," and "."
            feePerKbFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
            
            if ([decimalSeparator isEqualToString:@"."]) {
                return [feePerKbFormatter stringFromNumber:amountNumber];;
            } else {
                [feePerKbFormatter setDecimalSeparator:decimalSeparator];
                return [feePerKbFormatter stringFromNumber:amountNumber];
            }
        }
        
        return displayString;
    }
}

- (void)alertUserToChangeFee
{
    NSString *feePerKbString = [self convertFloatToString:self.currentFeePerKb forDisplay:NO];
    UIAlertController *alertForChangingFeePerKb = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_CHANGE_FEE_TITLE message:[[NSString alloc] initWithFormat:BC_STRING_SETTINGS_CHANGE_FEE_MESSAGE_ARGUMENT, feePerKbString] preferredStyle:UIAlertControllerStyleAlert];
    [alertForChangingFeePerKb addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        BCSecureTextField *secureTextField = (BCSecureTextField *)textField;
        secureTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        secureTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        secureTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        secureTextField.text = feePerKbString;
        secureTextField.text = [textField.text stringByReplacingOccurrencesOfString:@"." withString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
        secureTextField.keyboardType = UIKeyboardTypeDecimalPad;
        secureTextField.delegate = self;
        self.changeFeeTextField = secureTextField;
    }];
    [alertForChangingFeePerKb addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    [alertForChangingFeePerKb addAction:[UIAlertAction actionWithTitle:BC_STRING_DONE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        BCSecureTextField *textField = (BCSecureTextField *)[[alertForChangingFeePerKb textFields] firstObject];
        NSString *decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
        NSString *convertedText = [textField.text stringByReplacingOccurrencesOfString:decimalSeparator withString:@"."];
        float fee = [convertedText floatValue];
        if (fee > 0.01 || fee == 0) {
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:BC_STRING_ERROR message:BC_STRING_SETTINGS_ERROR_FEE_OUT_OF_RANGE preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:errorAlert animated:YES completion:nil];
            return;
        }
        
        [self confirmChangeFee:fee];
    }]];
    [self presentViewController:alertForChangingFeePerKb animated:YES completion:nil];
}

- (void)confirmChangeFee:(float)fee
{
    NSNumber *unconvertedFee = [NSNumber numberWithFloat:fee * [[NSNumber numberWithInt:SATOSHI] floatValue]];
    uint64_t convertedFee = (uint64_t)[unconvertedFee longLongValue];
    [app.wallet setTransactionFee:convertedFee];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:feePerKb inSection:feesSection]] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Change Mobile Number

- (NSString *)getMobileNumber
{
    return [self.accountInfoDictionary objectForKey:DICTIONARY_KEY_ACCOUNT_SETTINGS_SMS_NUMBER];
}

- (void)alertUserToChangeMobileNumber
{
    UIAlertController *alertForChangingMobileNumber = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_CHANGE_MOBILE_NUMBER message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertForChangingMobileNumber addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        self.isEnablingTwoStepSMS = NO;
    }]];
    [alertForChangingMobileNumber addAction:[UIAlertAction actionWithTitle:BC_STRING_SETTINGS_VERIFY style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self changeMobileNumber:[[alertForChangingMobileNumber textFields] firstObject].text];
    }]];
    [alertForChangingMobileNumber addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        BCSecureTextField *secureTextField = (BCSecureTextField *)textField;
        secureTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        secureTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        secureTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        secureTextField.tag = textFieldTagChangeMobileNumber;
        secureTextField.delegate = self;
        secureTextField.keyboardType = UIKeyboardTypePhonePad;
        secureTextField.returnKeyType = UIReturnKeyDone;
        secureTextField.text = self.mobileNumberString;
    }];
    [self presentViewController:alertForChangingMobileNumber animated:YES completion:nil];
}

- (void)changeMobileNumber:(NSString *)newNumber
{
    [app.wallet changeMobileNumber:newNumber];
    
    self.enteredMobileNumberString = newNumber;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeMobileNumberSuccess) name:NOTIFICATION_KEY_CHANGE_MOBILE_NUMBER_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeMobileNumberError) name:NOTIFICATION_KEY_CHANGE_MOBILE_NUMBER_ERROR object:nil];
}

- (void)changeMobileNumberSuccess
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_MOBILE_NUMBER_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_MOBILE_NUMBER_ERROR object:nil];
    
    self.mobileNumberString = self.enteredMobileNumberString;
    
    [self alertUserToVerifyMobileNumber];
}

- (void)changeMobileNumberError
{
    self.isEnablingTwoStepSMS = NO;
    [self alertUserOfError:BC_STRING_SETTINGS_ERROR_INVALID_MOBILE_NUMBER];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_MOBILE_NUMBER_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_MOBILE_NUMBER_ERROR object:nil];
}

- (void)alertUserToVerifyMobileNumber
{
    UIAlertController *alertForVerifyingMobileNumber = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_VERIFY_ENTER_CODE message:[[NSString alloc] initWithFormat:BC_STRING_SETTINGS_SENT_TO_ARGUMENT, self.mobileNumberString] preferredStyle:UIAlertControllerStyleAlert];
    [alertForVerifyingMobileNumber addAction:[UIAlertAction actionWithTitle:BC_STRING_SETTINGS_VERIFY_MOBILE_RESEND style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self changeMobileNumber:self.mobileNumberString];
    }]];
    [alertForVerifyingMobileNumber addAction:[UIAlertAction actionWithTitle:BC_STRING_SETTINGS_NEW_MOBILE_NUMBER style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self alertUserToChangeMobileNumber];
    }]];
    [alertForVerifyingMobileNumber addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // If the user cancels right after adding a legitimate number, update accountInfo
        self.isEnablingTwoStepSMS = NO;
        [self getAccountInfo];
    }]];
    [alertForVerifyingMobileNumber addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        BCSecureTextField *secureTextField = (BCSecureTextField *)textField;
        secureTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        secureTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        secureTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        secureTextField.tag = textFieldTagVerifyMobileNumber;
        secureTextField.delegate = self;
        secureTextField.returnKeyType = UIReturnKeyDone;
        secureTextField.placeholder = BC_STRING_ENTER_VERIFICATION_CODE;
    }];
    [self presentViewController:alertForVerifyingMobileNumber animated:YES completion:nil];
}

- (void)verifyMobileNumber:(NSString *)code
{
    [app.wallet verifyMobileNumber:code];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(verifyMobileNumberSuccess) name:NOTIFICATION_KEY_VERIFY_MOBILE_NUMBER_SUCCESS object:nil];
    // Mobile number error appears through sendEvent
}

- (void)verifyMobileNumberSuccess
{
    [self getAccountInfo];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_VERIFY_MOBILE_NUMBER_SUCCESS object:nil];
    
    if (self.isEnablingTwoStepSMS) {
        self.isEnablingTwoStepSMS = NO;
        [self enableTwoStepForSMS];
        return;
    }
    
    [self alertUserOfSuccess:BC_STRING_SETTINGS_MOBILE_NUMBER_VERIFIED];
}

#pragma mark - Change Touch ID

- (void)switchTouchIDTapped
{
    NSString *errorString = [app checkForTouchIDAvailablility];
    if (!errorString) {
        [self toggleTouchID];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:USER_DEFAULTS_KEY_TOUCH_ID_ENABLED];
        
        UIAlertController *alertTouchIDError = [UIAlertController alertControllerWithTitle:BC_STRING_ERROR message:errorString preferredStyle:UIAlertControllerStyleAlert];
        [alertTouchIDError addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:securityTouchID inSection:securitySection];
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
        [self presentViewController:alertTouchIDError animated:YES completion:nil];
    }
}

- (void)toggleTouchID
{
    BOOL touchIDEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_KEY_TOUCH_ID_ENABLED];
    
    if (!touchIDEnabled == YES) {
        UIAlertController *alertForTogglingTouchID = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_SECURITY_USE_TOUCH_ID_AS_PIN message:BC_STRING_TOUCH_ID_WARNING preferredStyle:UIAlertControllerStyleAlert];
        [alertForTogglingTouchID addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:securityTouchID inSection:securitySection];
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
        [alertForTogglingTouchID addAction:[UIAlertAction actionWithTitle:BC_STRING_CONTINUE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [app validatePINOptionally];
        }]];
        [self presentViewController:alertForTogglingTouchID animated:YES completion:nil];
    } else {
        [app disabledTouchID];
        [[NSUserDefaults standardUserDefaults] setBool:!touchIDEnabled forKey:USER_DEFAULTS_KEY_TOUCH_ID_ENABLED];
    }
}

#pragma mark - Change Two Step

- (void)alertUserToChangeTwoStepVerification
{
    NSString *alertTitle;
    BOOL isTwoStepEnabled = NO;
    if ([self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_TWO_STEP_TYPE] intValue] == TWO_STEP_AUTH_TYPE_SMS) {
        alertTitle = [NSString stringWithFormat:BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_ENABLED_ARGUMENT, BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_SMS];
        isTwoStepEnabled = YES;
    } else if ([self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_TWO_STEP_TYPE] intValue] == TWO_STEP_AUTH_TYPE_GOOGLE) {
        alertTitle = [NSString stringWithFormat:BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_ENABLED_ARGUMENT, BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_GOOGLE];
        isTwoStepEnabled = YES;
    } else {
        alertTitle = BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_DISABLED;
    }
    
    UIAlertController *alertForChangingTwoStep = [UIAlertController alertControllerWithTitle:alertTitle message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertForChangingTwoStep addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler: nil]];
    [alertForChangingTwoStep addAction:[UIAlertAction actionWithTitle:isTwoStepEnabled ? BC_STRING_DISABLE : BC_STRING_ENABLE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (!isTwoStepEnabled) {
            [self alertUserThatOnlySMSCanBeEnabled];
        } else {
            [self changeTwoStepVerification];
        }
    }]];
    [self presentViewController:alertForChangingTwoStep animated:YES completion:nil];
}

- (void)alertUserThatOnlySMSCanBeEnabled
{
    UIAlertController *alertForChangingTwoStep = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION message:BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_MESSAGE_SMS_ONLY preferredStyle:UIAlertControllerStyleAlert];
    [alertForChangingTwoStep addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler: nil]];
    [alertForChangingTwoStep addAction:[UIAlertAction actionWithTitle:BC_STRING_CONTINUE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self changeTwoStepVerification];
    }]];
    [self presentViewController:alertForChangingTwoStep animated:YES completion:nil];
}

- (void)changeTwoStepVerification
{
    if ([app checkInternetConnection]) {
        
        if ([self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_TWO_STEP_TYPE] intValue] == TWO_STEP_AUTH_TYPE_NONE) {
            self.isEnablingTwoStepSMS = YES;
            if ([self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_SMS_NUMBER] isEqualToString:self.mobileNumberString]) {
                [self changeMobileNumber:self.mobileNumberString];
            } else {
                [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:accountDetailsMobileNumber inSection:accountDetailsSection]];
            }
        } else {
            [self disableTwoStep];
        }
    }
}

- (void)enableTwoStepForSMS
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTwoStepSuccess) name:NOTIFICATION_KEY_CHANGE_TWO_STEP_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTwoStepError) name:NOTIFICATION_KEY_CHANGE_TWO_STEP_ERROR object:nil];
    [app.wallet enableTwoStepVerificationForSMS];
}

- (void)disableTwoStep
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTwoStepSuccess) name:NOTIFICATION_KEY_CHANGE_TWO_STEP_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTwoStepError) name:NOTIFICATION_KEY_CHANGE_TWO_STEP_ERROR object:nil];
    [app.wallet disableTwoStepVerification];
}

- (void)resetTwoStepStatus
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_TWO_STEP_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_TWO_STEP_ERROR object:nil];
}

- (void)changeTwoStepSuccess
{
    [self resetTwoStepStatus];
    [self getAccountInfo];
}

- (void)changeTwoStepError
{
    [self resetTwoStepStatus];
    [self getAccountInfo];
}

#pragma mark - Change Email

- (BOOL)hasAddedEmail
{
    return [self.accountInfoDictionary objectForKey:DICTIONARY_KEY_ACCOUNT_SETTINGS_EMAIL] ? YES : NO;
}

- (BOOL)hasVerifiedEmail
{
    return [[self.accountInfoDictionary objectForKey:DICTIONARY_KEY_ACCOUNT_SETTINGS_EMAIL_VERIFIED] boolValue];
}

- (NSString *)getUserEmail
{
    return [self.accountInfoDictionary objectForKey:DICTIONARY_KEY_ACCOUNT_SETTINGS_EMAIL];
}

- (void)alertUserToChangeEmail:(BOOL)hasAddedEmail
{
    NSString *alertViewTitle = hasAddedEmail ? BC_STRING_SETTINGS_CHANGE_EMAIL :BC_STRING_ADD_EMAIL;
    
    UIAlertController *alertForChangingEmail = [UIAlertController alertControllerWithTitle:alertViewTitle message:BC_STRING_PLEASE_PROVIDE_AN_EMAIL_ADDRESS preferredStyle:UIAlertControllerStyleAlert];
    [alertForChangingEmail addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // If the user cancels right after adding a legitimate email address, update accountInfo
        UITableViewCell *emailCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:accountDetailsEmail inSection:accountDetailsSection]];
        if (([emailCell.detailTextLabel.text isEqualToString:BC_STRING_SETTINGS_UNVERIFIED] && [alertForChangingEmail.title isEqualToString:BC_STRING_SETTINGS_CHANGE_EMAIL]) || ![[self getUserEmail] isEqualToString:self.emailString]) {
            [self getAccountInfo];
        }
    }]];
    [alertForChangingEmail addAction:[UIAlertAction actionWithTitle:BC_STRING_SETTINGS_VERIFY style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self changeEmail:[[alertForChangingEmail textFields] firstObject].text];
    }]];
    [alertForChangingEmail addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        BCSecureTextField *secureTextField = (BCSecureTextField *)textField;
        secureTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        secureTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        secureTextField.returnKeyType = UIReturnKeyDone;
        secureTextField.text = hasAddedEmail ? [self getUserEmail] : @"";
    }];
    [self presentViewController:alertForChangingEmail animated:YES completion:nil];
}

- (void)alertUserToVerifyEmail
{
    UIAlertController *alertForVerifyingEmail = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_VERIFY_ENTER_CODE message:[[NSString alloc] initWithFormat:BC_STRING_SETTINGS_SENT_TO_ARGUMENT, self.emailString] preferredStyle:UIAlertControllerStyleAlert];
    [alertForVerifyingEmail addAction:[UIAlertAction actionWithTitle:BC_STRING_SETTINGS_VERIFY_EMAIL_RESEND style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self resendVerificationEmail];
    }]];
    [alertForVerifyingEmail addAction:[UIAlertAction actionWithTitle:BC_STRING_SETTINGS_NEW_EMAIL_ADDRESS style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // Give time for the alertView to fully dismiss, otherwise its keyboard will pop up if entered email is invalid
        dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, 0.5f * NSEC_PER_SEC);
        dispatch_after(delayTime, dispatch_get_main_queue(), ^{
            [self alertUserToChangeEmail:YES];
        });
    }]];
    [alertForVerifyingEmail addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self getAccountInfo];
    }]];
    [alertForVerifyingEmail addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        BCSecureTextField *secureTextField = (BCSecureTextField *)textField;
        secureTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        secureTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        secureTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        secureTextField.tag = textFieldTagVerifyEmail;
        secureTextField.delegate = self;
        secureTextField.returnKeyType = UIReturnKeyDone;
        secureTextField.placeholder = BC_STRING_ENTER_VERIFICATION_CODE;
    }];
    [self presentViewController:alertForVerifyingEmail animated:YES completion:nil];
}

- (void)resendVerificationEmail
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resendVerificationEmailSuccess) name:NOTIFICATION_KEY_RESEND_VERIFICATION_EMAIL_SUCCESS object:nil];
    
    [app.wallet resendVerificationEmail:self.emailString];
}

- (void)resendVerificationEmailSuccess
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_RESEND_VERIFICATION_EMAIL_SUCCESS object:nil];
    
    [self alertUserToVerifyEmail];
}

- (void)changeEmail:(NSString *)emailString
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeEmailSuccess) name:NOTIFICATION_KEY_CHANGE_EMAIL_SUCCESS object:nil];
    
    self.enteredEmailString = emailString;
    
    [app.wallet changeEmail:emailString];
}

- (void)changeEmailSuccess
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_EMAIL_SUCCESS object:nil];
    
    self.emailString = self.enteredEmailString;
    
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, 0.5f * NSEC_PER_SEC);
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{
        [self alertUserToVerifyEmail];
    });
}

- (void)verifyEmailWithCode:(NSString *)codeString
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(verifyEmailWithCodeSuccess) name:NOTIFICATION_KEY_VERIFY_EMAIL_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(verifyEmailWithCodeError) name:NOTIFICATION_KEY_VERIFY_EMAIL_ERROR object:nil];
    
    [app.wallet verifyEmailWithCode:codeString];
}

- (void)verifyEmailWithCodeSuccess
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_VERIFY_EMAIL_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_VERIFY_EMAIL_ERROR object:nil];
    
    [self getAccountInfo];
    
    [self alertUserOfSuccess:BC_STRING_SETTINGS_EMAIL_VERIFIED];
}

- (void)verifyEmailWithCodeError
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_VERIFY_EMAIL_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_VERIFY_EMAIL_ERROR object:nil];
    
    [self alertUserOfError:BC_STRING_SETTINGS_VERIFY_INVALID_CODE];
}

#pragma mark - Change Password Hint

- (void)alertUserToChangePasswordHint
{
    UIAlertController *alertForChangingPasswordHint = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD_HINT message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertForChangingPasswordHint addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    [alertForChangingPasswordHint addAction:[UIAlertAction actionWithTitle:BC_STRING_UPDATE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *passwordHint = [[alertForChangingPasswordHint textFields] firstObject].text;
        if ([[passwordHint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""] || !passwordHint) {
            [self alertUserThatAllWhiteSpaceCharactersClearsHint];
        } else {
            if ([self isHintValid:passwordHint]) {
                [self changePasswordHint:passwordHint];
            }
        }
    }]];
    NSString *passwordHint = self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_PASSWORD_HINT];
    [alertForChangingPasswordHint addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        BCSecureTextField *secureTextField = (BCSecureTextField *)textField;
        secureTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        secureTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        secureTextField.tag = textFieldTagChangePasswordHint;
        secureTextField.returnKeyType = UIReturnKeyDone;
        secureTextField.text = passwordHint;
    }];
    [self presentViewController:alertForChangingPasswordHint animated:YES completion:nil];
}

- (void)alertUserThatAllWhiteSpaceCharactersClearsHint
{
    UIAlertController *alertForClearingPasswordHint = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD_HINT message:BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD_HINT_WARNING_ALL_WHITESPACE preferredStyle:UIAlertControllerStyleAlert];
    [alertForClearingPasswordHint addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    [alertForClearingPasswordHint addAction:[UIAlertAction actionWithTitle:BC_STRING_CONTINUE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self changePasswordHint:@""];
    }]];
    [self presentViewController:alertForClearingPasswordHint animated:YES completion:nil];
}

- (void)changePasswordHint:(NSString *)hint
{
    UITableViewCell *changePasswordHintCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:securityPasswordHint inSection:securitySection]];
    changePasswordHintCell.userInteractionEnabled = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changePasswordHintSuccess) name:NOTIFICATION_KEY_CHANGE_PASSWORD_HINT_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changePasswordHintError) name:NOTIFICATION_KEY_CHANGE_PASSWORD_HINT_ERROR object:nil];
    [app.wallet updatePasswordHint:hint];
}

- (BOOL)isHintValid:(NSString *)hint
{
    if ([app.wallet isCorrectPassword:hint]) {
        [self alertUserOfError:BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD_HINT_ERROR_SAME_AS_PASSWORD];
        return NO;
    } else if ([app.wallet validateSecondPassword:hint]) {
        [self alertUserOfError:BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD_HINT_ERROR_SAME_AS_SECOND_PASSWORD];
        return NO;
    }
    return YES;
}

- (void)changePasswordHintSuccess
{
    [self resetPasswordHintCell];
    [self alertUserOfSuccess:BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD_HINT_SUCCESS];
    [self getAccountInfo];
}

- (void)changePasswordHintError
{
    [self resetPasswordHintCell];
    [self alertUserOfError:BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD_HINT_ERROR_INVALID_CHARACTERS];
}

- (void)resetPasswordHintCell
{
    UITableViewCell *changePasswordHintCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:securityPasswordHint inSection:securitySection]];
    changePasswordHintCell.userInteractionEnabled = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_PASSWORD_HINT_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_PASSWORD_HINT_ERROR object:nil];
}

#pragma mark - Change Password

- (void)changePassword
{
    [self performSegueWithIdentifier:@"changePassword" sender:nil];
}

#pragma mark - TextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    __weak SettingsTableViewController *weakSelf = self;
    
    [self dismissViewControllerAnimated:YES completion:^{
        if (textField.tag == textFieldTagVerifyEmail) {
            [weakSelf verifyEmailWithCode:textField.text];
            
        } else if (textField.tag == textFieldTagVerifyMobileNumber) {
            [weakSelf verifyMobileNumber:textField.text];
            
        } else if (textField.tag == textFieldTagChangeMobileNumber) {
            [weakSelf changeMobileNumber:textField.text];
        }
    }];
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.changeFeeTextField) {
        
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        NSArray  *points = [newString componentsSeparatedByString:@"."];
        NSArray  *commas = [newString componentsSeparatedByString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
        
        // Only one comma or point in input field allowed
        if ([points count] > 2 || [commas count] > 2)
            return NO;
        
        // Only 1 leading zero
        if (points.count == 1 || commas.count == 1) {
            if (range.location == 1 && ![string isEqualToString:@"."] && ![string isEqualToString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]] && [textField.text isEqualToString:@"0"]) {
                return NO;
            }
        }
        
        NSString *decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
        NSString *numbersWithDecimalSeparatorString = [[NSString alloc] initWithFormat:@"%@%@", NUMBER_KEYPAD_CHARACTER_SET_STRING, decimalSeparator];
        NSCharacterSet *characterSetFromString = [NSCharacterSet characterSetWithCharactersInString:newString];
        NSCharacterSet *numbersAndDecimalCharacterSet = [NSCharacterSet characterSetWithCharactersInString:numbersWithDecimalSeparatorString];
        
        // Only accept numbers and decimal representations
        if (![numbersAndDecimalCharacterSet isSupersetOfSet:characterSetFromString]) {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:SEGUE_IDENTIFIER_CURRENCY]) {
        SettingsSelectorTableViewController *settingsSelectorTableViewController = segue.destinationViewController;
        settingsSelectorTableViewController.itemsDictionary = self.availableCurrenciesDictionary;
        settingsSelectorTableViewController.allCurrencySymbolsDictionary = self.allCurrencySymbolsDictionary;
        settingsSelectorTableViewController.delegate = self;
    } else if ([segue.identifier isEqualToString:SEGUE_IDENTIFIER_ABOUT]) {
        SettingsAboutViewController *aboutViewController = segue.destinationViewController;
        if ([sender isEqualToString:SEGUE_SENDER_TERMS_OF_SERVICE]) {
            aboutViewController.urlTargetString = TERMS_OF_SERVICE_URL;
        } else if ([sender isEqualToString:SEGUE_SENDER_PRIVACY_POLICY]) {
            aboutViewController.urlTargetString = PRIVACY_POLICY_URL;
        }
    } else if ([segue.identifier isEqualToString:SEGUE_IDENTIFIER_BTC_UNIT]) {
        SettingsBitcoinUnitTableViewController *settingsBtcUnitTableViewController = segue.destinationViewController;
        settingsBtcUnitTableViewController.itemsDictionary = self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_BTC_CURRENCIES];
        settingsBtcUnitTableViewController.delegate = self;
    }
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    switch (indexPath.section) {
        case accountDetailsSection: {
            switch (indexPath.row) {
                case accountDetailsIdentifier: {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BC_STRING_SETTINGS_COPY_GUID message:BC_STRING_SETTINGS_COPY_GUID_WARNING preferredStyle:UIAlertControllerStyleActionSheet];
                    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:BC_STRING_COPY_TO_CLIPBOARD style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                        DLog("User confirmed copying GUID");
                        [UIPasteboard generalPasteboard].string = app.wallet.guid;
                    }];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil];
                    [alert addAction:cancelAction];
                    [alert addAction:copyAction];
                    [self presentViewController:alert animated:YES completion:nil];
                    return;
                }
                case accountDetailsMobileNumber: {
                    if ([self.accountInfoDictionary objectForKey:DICTIONARY_KEY_ACCOUNT_SETTINGS_SMS_NUMBER]) {
                        if ([self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_SMS_VERIFIED] boolValue] == YES) {
                            [self alertUserToChangeMobileNumber];
                        } else {
                            [self alertUserToVerifyMobileNumber];
                        }
                    } else {
                        [self alertUserToChangeMobileNumber];
                    }
                    return;
                }
                case accountDetailsEmail: {
                    if (![self hasAddedEmail]) {
                        [self alertUserToChangeEmail:NO];
                    } else if ([self hasVerifiedEmail]) {
                        [self alertUserToChangeEmail:YES];
                    } else {
                        [self alertUserToVerifyEmail];
                    } return;
                }
            }
            return;
        }
        case displaySection: {
            switch (indexPath.row) {
                case displayLocalCurrency: {
                    [self performSegueWithIdentifier:SEGUE_IDENTIFIER_CURRENCY sender:nil];
                    return;
                }
                case displayBtcUnit: {
                    [self performSegueWithIdentifier:SEGUE_IDENTIFIER_BTC_UNIT sender:nil];
                    return;
                }
            }
            return;
        }
        case feesSection: {
            switch (indexPath.row) {
                case feePerKb: {
                    [self alertUserToChangeFee];
                    return;
                }
            }
            return;
        }
        case securitySection: {
            switch (indexPath.row) {
                case securityTwoStep: {
                    [self alertUserToChangeTwoStepVerification];
                    return;
                }
                case securityPasswordHint: {
                    [self alertUserToChangePasswordHint];
                    return;
                }
                case securityPasswordChange: {
                    [self changePassword];
                    return;
                }
            }
            return;
        }
        case aboutSection: {
            switch (indexPath.row) {
                case aboutTermsOfService: {
                    [self performSegueWithIdentifier:SEGUE_IDENTIFIER_ABOUT sender:SEGUE_SENDER_TERMS_OF_SERVICE];
                    return;
                }
                case aboutPrivacyPolicy: {
                    [self performSegueWithIdentifier:SEGUE_IDENTIFIER_ABOUT sender:SEGUE_SENDER_PRIVACY_POLICY];
                    return;
                }
            }
            return;
        }
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
#ifdef TOUCH_ID_ENABLED
    return 5;
#else
    return 4;
#endif
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case accountDetailsSection: return 3;
        case displaySection: return 2;
        case feesSection: return 1;
        case securitySection: return securityTouchID < 0 ? 3 : 4;
        case aboutSection: return 2;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case accountDetailsSection: return BC_STRING_SETTINGS_ACCOUNT_DETAILS;
        case displaySection: return BC_STRING_SETTINGS_DISPLAY_PREFERENCES;
        case feesSection: return BC_STRING_SETTINGS_FEES;
        case securitySection: return BC_STRING_SETTINGS_SECURITY;
        case aboutSection: return BC_STRING_SETTINGS_ABOUT;
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    switch (section) {
        case accountDetailsSection: return BC_STRING_SETTINGS_EMAIL_FOOTER;
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.font = [SettingsTableViewController fontForCell];
    cell.detailTextLabel.font = [SettingsTableViewController fontForCell];
    
    switch (indexPath.section) {
        case accountDetailsSection: {
            switch (indexPath.row) {
                case accountDetailsIdentifier: {
                    UITableViewCell *cellWithSubtitle = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
                    cellWithSubtitle.selectionStyle = UITableViewCellSelectionStyleNone;
                    cellWithSubtitle.textLabel.font = [SettingsTableViewController fontForCell];
                    cellWithSubtitle.textLabel.text = BC_STRING_SETTINGS_WALLET_ID;
                    cellWithSubtitle.detailTextLabel.text = app.wallet.guid;
                    cellWithSubtitle.detailTextLabel.font = [SettingsTableViewController fontForCellSubtitle];
                    cellWithSubtitle.detailTextLabel.textColor = [UIColor grayColor];
                    cellWithSubtitle.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    return cellWithSubtitle;
                }
                case accountDetailsMobileNumber: {
                    cell.textLabel.text = BC_STRING_SETTINGS_MOBILE_NUMBER;
                    if ([self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_SMS_VERIFIED] boolValue] == YES) {
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_VERIFIED;
                        cell.detailTextLabel.textColor = COLOR_BUTTON_GREEN;
                    } else {
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_UNVERIFIED;
                        cell.detailTextLabel.textColor = COLOR_BUTTON_RED;
                    }
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    return cell;
                }
                case accountDetailsEmail: {
                    cell.textLabel.text = BC_STRING_SETTINGS_EMAIL;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    
                    if ([self getUserEmail] != nil && [self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_EMAIL_VERIFIED] boolValue] == YES) {
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_VERIFIED;
                        cell.detailTextLabel.textColor = COLOR_BUTTON_GREEN;
                    } else {
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_UNVERIFIED;
                        cell.detailTextLabel.textColor = COLOR_BUTTON_RED;
                    }
                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    return cell;
                }
            }
        }
        case displaySection: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
            switch (indexPath.row) {
                case displayLocalCurrency: {
                    NSString *selectedCurrencyCode = [self getLocalSymbolFromLatestResponse].code;
                    NSString *currencyName = self.availableCurrenciesDictionary[selectedCurrencyCode];
                    cell.textLabel.text = BC_STRING_SETTINGS_LOCAL_CURRENCY;
                    cell.detailTextLabel.text = [[NSString alloc] initWithFormat:@"%@ (%@)", currencyName, self.allCurrencySymbolsDictionary[selectedCurrencyCode][@"symbol"]];
                    if (currencyName == nil || self.allCurrencySymbolsDictionary[selectedCurrencyCode][@"symbol"] == nil) {
                        cell.detailTextLabel.text = @"";
                    }
                    return cell;
                }
                case displayBtcUnit: {
                    NSString *selectedCurrencyCode = [self getBtcSymbolFromLatestResponse].name;
                    cell.textLabel.text = BC_STRING_SETTINGS_BTC;
                    cell.detailTextLabel.text = selectedCurrencyCode;
                    if (selectedCurrencyCode == nil) {
                        cell.detailTextLabel.text = @"";
                    }
                    return cell;
                }
            }
        }
        case feesSection: {
            switch (indexPath.row) {
                case feePerKb: {
                    cell.textLabel.text = BC_STRING_SETTINGS_FEE_PER_KB;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.detailTextLabel.text = [[NSString alloc] initWithFormat:BC_STRING_SETTINGS_FEE_ARGUMENT_BTC, [self convertFloatToString:[self getFeePerKb] forDisplay:YES]];
                    return cell;
                }
            }
        }
        case securitySection: {
            switch (indexPath.row) {
                case securityTwoStep: {
                    cell.textLabel.text = BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION;
                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    int authType = [self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_TWO_STEP_TYPE] intValue];
                    if (authType == TWO_STEP_AUTH_TYPE_SMS) {
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_SMS;
                        cell.detailTextLabel.textColor = COLOR_BUTTON_GREEN;
                    } else if (authType == TWO_STEP_AUTH_TYPE_GOOGLE) {
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_SECURITY_TWO_STEP_VERIFICATION_GOOGLE;
                        cell.detailTextLabel.textColor = COLOR_BUTTON_GREEN;
                    } else {
                        cell.detailTextLabel.text = BC_STRING_DISABLED;
                        cell.detailTextLabel.textColor = COLOR_BUTTON_RED;
                    }
                    return cell;
                }
                case securityPasswordHint: {
                    cell.textLabel.text = BC_STRING_SETTINGS_SECURITY_PASSWORD_HINT;
                    NSString *passwordHint = self.accountInfoDictionary[DICTIONARY_KEY_ACCOUNT_SETTINGS_PASSWORD_HINT];
                    if ([[passwordHint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""] || !passwordHint) {
                        cell.detailTextLabel.textColor = COLOR_BUTTON_RED;
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_NOT_STORED;
                    } else {
                        cell.detailTextLabel.textColor = COLOR_BUTTON_GREEN;
                        cell.detailTextLabel.text = BC_STRING_SETTINGS_STORED;
                    }
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    return cell;
                }
                case securityPasswordChange: {
                    cell.textLabel.text = BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    return cell;
                }
                case securityTouchID: {
                    cell = [tableView dequeueReusableCellWithIdentifier:REUSE_IDENTIFIER_TOUCH_ID_FOR_PIN];
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:REUSE_IDENTIFIER_TOUCH_ID_FOR_PIN];
                    cell.textLabel.font = [SettingsTableViewController fontForCell];
                    cell.textLabel.text = BC_STRING_SETTINGS_SECURITY_USE_TOUCH_ID_AS_PIN;
                    UISwitch *switchForTouchID = [[UISwitch alloc] init];
                    BOOL touchIDEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_KEY_TOUCH_ID_ENABLED];
                    switchForTouchID.on = touchIDEnabled;
                    [switchForTouchID addTarget:self action:@selector(switchTouchIDTapped) forControlEvents:UIControlEventTouchUpInside];
                    cell.accessoryView = switchForTouchID;
                    return cell;
                }
            }
        }
        case aboutSection: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            switch (indexPath.row) {
                case aboutTermsOfService: {
                    cell.textLabel.text = BC_STRING_SETTINGS_TERMS_OF_SERVICE;
                    return cell;
                }
                case aboutPrivacyPolicy: {
                    cell.textLabel.text = BC_STRING_SETTINGS_PRIVACY_POLICY;
                    return cell;
                }
            }
        }        default: return nil;
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL hasLoadedAccountInfoDictionary = self.accountInfoDictionary ? YES : NO;
    
    if (!hasLoadedAccountInfoDictionary || [[[NSUserDefaults standardUserDefaults] objectForKey:USER_DEFAULTS_KEY_LOADED_SETTINGS] boolValue] == NO) {
        [self alertUserOfErrorLoadingSettings];
        return nil;
    } else {
        return indexPath;
    }
}

@end