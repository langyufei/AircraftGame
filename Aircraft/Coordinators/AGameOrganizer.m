//
//  AGameOrganizer.m
//  Aircraft
//
//  Created by Yufei Lang on 1/1/13.
//  Copyright (c) 2013 Yufei Lang. All rights reserved.
//

#import "AGameOrganizer.h"
#import "ABattleResultViewController.h"

@interface AGameOrganizer ()
{
    AGuideViewController *_guideVC;
    ABattleResultViewController *_resultVC;
    ASavedGameRecord *_gameRecord;
    NSArray *_competitorAircrafts;
    NSArray *_selfAircrafts;
    ABattleResultInfoModel *_resultModel;
}

@property (strong, nonatomic) AChattingViewController *chatVC;
@property (strong, nonatomic) ABattleFieldViewController *battleFldVCEnemy;
@property (strong, nonatomic) ABattleFieldViewController *battleFldVCSelf;
@property (strong, nonatomic) AOperationPanelViewController *opPanelVC;

- (BOOL)checkReadyForPlacingAircrafts;
- (void)setupPlacingAircraftGuide;
- (void)setupPlayScreenGuide;
- (void)setupAttackPlayGuide;
- (void)startTheGame;
- (void)endBattleWithResult:(NSString *)resString keepConnectionAlive:(BOOL)YesOrNo;
- (void)saveCurrentGamingStatus;
@end

@implementation AGameOrganizer

@synthesize chatVC = _chatVC;
@synthesize whosTurn = _whosTurn;
@synthesize battleFldVCSelf = _battleFldVCSelf;
@synthesize battleFldVCEnemy = _battleFldVCEnemy;
@synthesize opPanelVC = _opPanelVC;
@synthesize communicator = _communicator;
@synthesize connectionType = _connectionType;

+ (AGameOrganizer *)sharedInstance
{
    static AGameOrganizer *organizer = nil;
    if (!organizer)
    {
        organizer = [[AGameOrganizer alloc] init];
    }
    return organizer;
}

- (id)init
{
    if (self = [super init])
    {
        self.connectionType = ConnectionTypeNone;
        _gameRecord = nil;
        _numberOfAircraftPlaced = [NSNumber numberWithInt:0];
        _numberOfAircraftDestroyed = [NSNumber numberWithInt:0];
        _numberOfSelfAircraftDestroyed  = [NSNumber numberWithInt:0];
        _whosTurn = AWhosTurnNone;
        _gameId = @"";
        _isDonePlacingAircrafts = NO;
    }
    return self;
}

- (void)reset
{
    [self.communicator closeConnection];
    self.chatVC = nil;
    self.battleFldVCEnemy = nil;
    self.battleFldVCSelf = nil;
    self.opPanelVC = nil;
    
    _numberOfAircraftPlaced = nil;
    _numberOfAircraftDestroyed = nil;
    _numberOfSelfAircraftDestroyed = nil;
    _isGameBegin = NO;  // default is NO
    _dateWhenGameBegin = nil;
    _dateWhenGameEnd = nil;
    _userStatus = nil;
    _competitorAircrafts = nil;
    _selfAircrafts = nil;
    _competitorStatus = nil;
    _gameId = nil;
    _competitorName = nil;
}

- (NSDictionary *)gameStatus
{
    NSMutableDictionary *statusDic = [NSMutableDictionary dictionary];
    
    // aircraft placed
    if (!_numberOfAircraftPlaced) _numberOfAircraftPlaced = [NSNumber numberWithInt:0];
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(statusDic, _numberOfAircraftPlaced, kGameStatusAircraftPlaced);
    
    // aircraft placed
    if (!_numberOfAircraftDestroyed) _numberOfAircraftDestroyed = [NSNumber numberWithInt:0];
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(statusDic, _numberOfAircraftDestroyed, kGameStatusAircraftDestroyed);
    
    // is game on
    NSMutableDictionary *gameBeginStatus = [NSMutableDictionary dictionary];
    id isGameOn = _isGameBegin?[NSNumber numberWithBool:YES]:[NSNumber numberWithBool:NO];
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(gameBeginStatus, isGameOn, @"isGameOn");
    id beginDate = _dateWhenGameBegin?_dateWhenGameBegin:[NSNull null];
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(gameBeginStatus, beginDate, @"beginDate");
    id endDate = _dateWhenGameEnd?_dateWhenGameEnd:[NSNull null];
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(gameBeginStatus, endDate, @"endDate");
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(statusDic, gameBeginStatus, kGameStatusBeginEndGame);
    
    NSMutableDictionary *playerStatus = [NSMutableDictionary dictionary];
    id user = _userStatus?_userStatus:[NSNull null];
    id competitor = _competitorStatus?_competitorStatus:[NSNull null];
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(playerStatus, user, @"user");
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(playerStatus, competitor, @"competitor");
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(statusDic, playerStatus, kGameStatusPlayer);
    
    NSMutableDictionary *networkStatus = [NSMutableDictionary dictionary];
    ConnectionType type = self.communicator.type;
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(networkStatus, [NSNumber numberWithInt:type], @"type");
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(networkStatus, [NSNumber numberWithBool:self.communicator.isConnect], @"isConnect");
    DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(statusDic, networkStatus, kGameStatusNetWork);
    
    return [NSDictionary dictionaryWithDictionary:statusDic];
}

- (BOOL)isGameBegin
{
    return _isGameBegin;
}

- (BOOL)isDonePlacingAircrafts
{
    return _isDonePlacingAircrafts;
}

- (void)startTheGame
{
    _isGameBegin = YES;
    _dateWhenGameBegin = [NSDate date];
    
    AUIPopView *popView = [AUIPopView popViewWithText:ALocalisedString(@"battle_start")
                                                image:[UIImage imageForBlueRectBackground] 
                                                 size:CGSizeMake(210, 90) 
                                     dissmissDuration:3.0];
    [popView show];
    
    [self.chatVC addNewMessage:ALocalisedString(@"battle_start") toChattingTableWithType:AChattingMsgTypeHelpMsg];
    
    [self.opPanelVC startTheGame];
    [self.battleFldVCEnemy displayBattleField];
    
    [self setupAttackPlayGuide];
    
    if (_whosTurn == AWhosTurnCompetitor)
    {
        
    }
    else if (_whosTurn == AWhosTurnUser)
    {
        
    }
    else //if (_whosTurn == AWhosTurnNone)
    {
        // do nothing
    }
}

- (void)endBattleWithResult:(NSString *)resString keepConnectionAlive:(BOOL)YesOrNo;
{
    _isGameBegin = NO;
    NSDate *endGameDate = [NSDate date];
    [self.opPanelVC endTheGame];
    
    if (!_resultModel)
        _resultModel= [[ABattleResultInfoModel alloc] init];
    _resultModel.gameId = _gameId;
    _resultModel.competitorName = _competitorName;
    _resultModel.resultString = resString;
    _resultModel.battleBeginDate = _dateWhenGameBegin;
    _resultModel.battleEndDate = endGameDate;
    _resultModel.timeSpentUser = self.opPanelVC.userSpendTime;
    _resultModel.timeSpentOpponent = self.opPanelVC.competitorSpendTime;
    _resultModel.selfNumberOfAttacks = self.battleFldVCEnemy.attackRecordAry.count;
    _resultModel.selfNumberOfHits = self.battleFldVCEnemy.numberOfHits;
    _resultModel.enemyNumberOfAttacks = self.battleFldVCSelf.attackRecordAry.count;
    _resultModel.enemyNumberOfHits = self.battleFldVCSelf.numberOfHits;
    
    if (!_resultVC)
    {
        _resultVC = [[ABattleResultViewController alloc] initWithResultModel:_resultModel];
        _resultVC.delegate = self;
    }
    else
    {
        _resultVC.resultModel = _resultModel;
        _resultVC.delegate = self;
    }
    
    [[AAppDelegate sharedInstance].navigationController.view addSubview:_resultVC.view];
    
    // show user how competitor placed aircrafts
    for (NSDictionary *aircraftDictionaty in _competitorAircrafts)
    {
        AAircraftModel *aircraftModel = [AAircraftModel aircraftFromSavableDictionary:aircraftDictionaty];
        [self.battleFldVCEnemy addAircraft:aircraftModel toFieldAsType:AAircraftImgRegularType withGesture:NO onBottom:YES];
    }
    
    if (!YesOrNo)
        [self reset];
}

#pragma mark - save/load game

- (void)saveCurrentGamingStatus
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gameRecordSaved:) name:kNotificationGameSaved object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveGameRecordFailed:) name:kNotificationSaveGameFailed object:nil];
    
    if (!_dateWhenGameBegin)
        _dateWhenGameBegin = [NSDate date];
    
    AGameRecordManager *recordMgr = [AGameRecordManager sharedInstance];
    
    recordMgr.sharedGameRecord.connectionType = self.communicator.type;
    recordMgr.sharedGameRecord.competitorName = _competitorName;
    recordMgr.sharedGameRecord.gameId = _gameId;
    recordMgr.sharedGameRecord.enemyAircrafts = _competitorAircrafts ? _competitorAircrafts : nil;
    recordMgr.sharedGameRecord.selfAircrafts = _selfAircrafts ? _selfAircrafts : nil;
    recordMgr.sharedGameRecord.selfAttackRecords = self.battleFldVCEnemy.attackRecordAry;
    recordMgr.sharedGameRecord.chattingRecords = [self.chatVC saveableChattingMessageArray];
    recordMgr.sharedGameRecord.enemyAttackRecords = self.battleFldVCSelf.attackRecordAry;
    recordMgr.sharedGameRecord.isMyTurn = [NSNumber numberWithBool:_whosTurn == AWhosTurnUser ? YES : NO];
    
    recordMgr.sharedGameRecord.startTimeSec = [NSString stringWithFormat:@"%f", [_dateWhenGameBegin timeIntervalSince1970]];
#warning TODO: total playing time should be added up instead of using time interval since now
    recordMgr.sharedGameRecord.totalTimeSec = [NSNumber numberWithFloat:[_dateWhenGameBegin timeIntervalSinceNow]];
    recordMgr.sharedGameRecord.selfTotalTimeSec = [NSNumber numberWithFloat:self.opPanelVC.userSpendTime];
    recordMgr.sharedGameRecord.enemyTotalTimeSec = [NSNumber numberWithFloat:self.opPanelVC.competitorSpendTime];
    
    [recordMgr saveGameToFile];
}

- (void)gameRecordSaved:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationGameSaved object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationSaveGameFailed object:nil];
    
    AGameRecordManager *recordMgr = notification.object;
    switch (recordMgr.actionType) 
    {
        case AActionTypeNone:
        {
        }
            break;
        case AActionTypeUserAction:
        {
            AUIPopView *popView = [AUIPopView popViewWithText:ALocalisedString(@"game_record_saved")
                                                        image:[UIImage imageForBlueRectBackground] 
                                                         size:CGSizeMake(240, 90) 
                                             dissmissDuration:3.5];
            [popView show];
            
            ANetMessageSave *saveMsg = [[ANetMessageSave alloc] init];
            saveMsg.gameId = recordMgr.sharedGameRecord.gameId;
            saveMsg.isMyTurn = _whosTurn == AWhosTurnUser ? YES : NO;
            saveMsg.attackRecords = [NSArray array];
            ANetMessage *netMsg = [ANetMessage messageWithFlag:kFlagSave message:saveMsg];
            [self.communicator sendMessage:netMsg];
            [AGameRecordManager sharedInstance].actionType = AActionTypeNone;
        }
            break;
        case AActionTypeCompetitorAction:
        {
            [self.chatVC addNewMessage:ALocalisedString(@"game_saved_request_by_competitor") toChattingTableWithType:AChattingMsgTypeHelpMsg];
            [AGameRecordManager sharedInstance].actionType = AActionTypeNone;
        }
            break;
        default:
            break;
    }
}

- (void)saveGameRecordFailed:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationGameSaved object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationSaveGameFailed object:nil];

    [self.chatVC addNewMessage:ALocalisedString(@"not_able_save_try_later") toChattingTableWithType:AChattingMsgTypeSystemMsg];
}

- (void)loadGameFromGameRecord:(ASavedGameRecord *)gameRecord
{
    _gameRecord = gameRecord;
    [self makeConnectionWithType:gameRecord.connectionType];
    [self loadGameInfoFromGameRecord:gameRecord sentBy:AUserTypeUser];
}

- (void)loadGameInfoFromGameRecord:(ASavedGameRecord *)gameRecord sentBy:(AUserType)userType
{
    if (userType != AUserTypeNone)
    {
        // battle field self
        [self.battleFldVCSelf loadDataFromGameRecord:gameRecord sentBy:userType];
        
        // battle field enemy
        [self.battleFldVCEnemy loadDataFromGameRecord:gameRecord sentBy:userType];
        
        // operation panel setup
        [self.opPanelVC loadDataFromGameRecord:gameRecord sentBy:userType];
        
        // chatting view setup
        [self.chatVC loadDataFromGameRecord:gameRecord sentBy:userType];
        
        [self loadDataFromGameRecord:gameRecord sentBy:userType];
    }
    else
        AAssert(NO, @"No sender type is given when loading the game.");
}

- (void)loadDataFromGameRecord:(ASavedGameRecord *)gameRecord sentBy:(AUserType)userType
{
    switch (userType)
    {
        case AUserTypeUser:
        {
            _numberOfAircraftPlaced = [NSNumber numberWithInt:3];
            _numberOfAircraftDestroyed = [NSNumber numberWithInt:self.battleFldVCEnemy.numberOfAircraftDestroyed];
            _numberOfSelfAircraftDestroyed = [NSNumber numberWithInt:self.battleFldVCSelf.numberOfAircraftDestroyed];
            
            _whosTurn = [gameRecord.isMyTurn boolValue] ? AWhosTurnUser : AWhosTurnCompetitor;
            _isDonePlacingAircrafts = YES;
            _isGameBegin = YES;
            _dateWhenGameBegin = [NSDate dateWithTimeIntervalSince1970:[gameRecord.startTimeSec doubleValue]];
            _gameId = gameRecord.gameId;
            
            _competitorAircrafts = gameRecord.enemyAircrafts;
            _selfAircrafts = gameRecord.selfAircrafts;
        }
            break;
        case AUserTypeOpponent:
        {
            _numberOfAircraftPlaced = [NSNumber numberWithInt:3];
            _numberOfSelfAircraftDestroyed = [NSNumber numberWithInt:self.battleFldVCEnemy.numberOfAircraftDestroyed];
            _numberOfAircraftDestroyed = [NSNumber numberWithInt:self.battleFldVCSelf.numberOfAircraftDestroyed];
            
            _whosTurn = [gameRecord.isMyTurn boolValue] ? AWhosTurnCompetitor : AWhosTurnUser;
            _isDonePlacingAircrafts = YES;
            _isGameBegin = YES;
            _dateWhenGameBegin = [NSDate dateWithTimeIntervalSince1970:[gameRecord.startTimeSec doubleValue]];
            _gameId = gameRecord.gameId;
            
            _selfAircrafts = gameRecord.enemyAircrafts;
            _competitorAircrafts = gameRecord.selfAircrafts;
        }
            break;
        default:
            break;
    }
}

#pragma mark - battle result screen

- (void)resultViewController:(ABattleResultViewController *)resultVC userPressOkBtnForResult:(ABattleResultInfoModel *)resultModel
{
    [resultVC.view removeFromSuperview];
}

- (void)resultViewController:(ABattleResultViewController *)resultVC userPressRematchBtnForResult:(ABattleResultInfoModel *)resultModel
{
#warning TODO: do the rematch here
}

#pragma mark - communication controls

- (void)makeConnectionWithType:(ConnectionType)type;
{
    if (!self.communicator)
    {
        self.communicator = [ACommunicator sharedInstance];
        self.communicator.delegate = self;
    }
    
    switch (type)
    {
        case ConnectionTypeNone:
        {
            [AErrorFacade errorWithDomain:kErrorDomainOrganizer knownCode:3002];
        }
            break;
        case ConnectionTypeBluetooth:
        {
            [self.communicator makeConnWithType:ConnectionTypeBluetooth];
        }
            break;
//        case AConnectionWiFi:
//        {
//        }
//            break;
        default:
            break;
    }
}

// connection delegates

- (void)connectionEstablishedWith:(NSString *)name
{
    NSString *connString;
    if (name && ![name isEqualToString:@""])
        connString = [NSString stringWithFormat:@"%@: %@", ALocalisedString(@"youve_connected_with"), name];
    else
        connString = [NSString stringWithFormat:@"%@", ALocalisedString(@"youve_connected_with_NULL")];
    
    _competitorName = name;
    
    [self.chatVC addNewMessage:connString toChattingTableWithType:AChattingMsgTypeSystemMsg];
    
    if (!_gameRecord)
        [self setupPlacingAircraftGuide];
    else
    {
        ANetMessageLoad *loadMsg = [ANetMessageLoad messageWIthGameRecord:_gameRecord];
        ANetMessage *netMessage = [ANetMessage messageWithFlag:kFlagLoad message:loadMsg];
        if ([self.communicator sendMessage:netMessage])
        {
            [self.opPanelVC startTheGame]; // start timing
        }
    }
}

- (void)connectionDisconnected:(NSError *)errorOrNil
{
    NSString *noticeStr;
    if (errorOrNil)
        noticeStr = [NSString stringWithFormat:@"%@ %@\n%@",
                     ALocalisedString(@"connection_lost_due_to"),
                     errorOrNil.localizedFailureReason,
                     ALocalisedString(@"restart_battle")];
    else
        noticeStr = [NSString stringWithFormat:@"%@\n%@",
                     ALocalisedString(@"connection_lost"),
                     ALocalisedString(@"restart_battle")];
    
    [self.chatVC addNewMessage:noticeStr toChattingTableWithType:AChattingMsgTypeSystemMsg];
    [self reset];
}

- (void)receivedNetMessage:(ANetMessage *)netMessage
{
    if ([netMessage.flag isEqualToString:kFlagInitial])
    {
        ANetMessageInitial *initialMsg = netMessage.message;
        NSDate *timestamp = netMessage.timestamp;
        
        NSString *receivedGameId = initialMsg.gameId;
        if ([receivedGameId caseInsensitiveCompare:_gameId] == NSOrderedAscending)
            _gameId = receivedGameId;
        
        _competitorAircrafts = [NSArray arrayWithArray:initialMsg.aircrafts];
        for (NSDictionary *aircraftDic in _competitorAircrafts)
            [self.battleFldVCEnemy addAircraftModelToBattleFieldModel:[AAircraftModel aircraftFromSavableDictionary:aircraftDic]];
        
        if (!_competitorStatus)
            _competitorStatus = [NSMutableDictionary dictionary];
        DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(_competitorStatus, [NSNumber numberWithBool:YES], @"isReady");
        DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(_competitorStatus, timestamp, @"date");
        
        if (_userStatus)
        {
            NSDate *userReadyDate = [_userStatus objectForKey:@"date"];
            if ([timestamp timeIntervalSinceDate:userReadyDate] <= 0)
            {
                _whosTurn = AWhosTurnCompetitor;
            }
            else
            {
                _whosTurn = AWhosTurnUser;
            }
        
            [self startTheGame];
        }
        else
        {
            [self.chatVC addNewMessage:ALocalisedString(@"your_opponent_is_ready") toChattingTableWithType:AChattingMsgTypeHelpMsg];
        }
    }
    else if ([netMessage.flag isEqualToString:kFlagInitialR])
    {
        
    }
    else if ([netMessage.flag isEqualToString:kFlagAttack])
    {
        ANetMessageAttack *attackMsg = (ANetMessageAttack *)netMessage.message;
        CGPoint attackPt = CGPointMake([attackMsg.row floatValue], [attackMsg.col floatValue]);
        NSString *attackResStr = [self.battleFldVCSelf attackResultInGridAtPoint:attackPt];
        
        [self.battleFldVCSelf addEnemyAttackRecord:attackPt];
        [self.battleFldVCSelf displayAttackResultAtPoint:attackPt resultString:attackResStr];
        
        ANetMessageAttackR *replyMsg = [[ANetMessageAttackR alloc] init];
        replyMsg.attackResult = attackResStr;
//        replyMsg.toolsResult =
        
        ANetMessage *netMessageR = [ANetMessage messageWithFlag:kFlagAttackR message:replyMsg];
        if ([self.communicator sendMessage:netMessageR])
        {
            _whosTurn = AWhosTurnUser;
            [self.opPanelVC switchTurn];
        }
//        else
#warning TODO: send again or seveal time to ensure delivery. If still failure, warn user.
    }
    else if ([netMessage.flag isEqualToString:kFlagAttackR])
    {
        ANetMessageAttackR *replyMsg = (ANetMessageAttackR *)netMessage.message;
        [self.battleFldVCEnemy displayPreviousAttackResultForString:replyMsg.attackResult];
//        if ([replyMsg.attackResult caseInsensitiveCompare:kAttackRDestroy] == NSOrderedSame)
//            [self enemyAircraftDestroyed];
    }
    else if ([netMessage.flag isEqualToString:kFlagChat])
    {
        ANetMessageChat *chatMsg = (ANetMessageChat *)netMessage.message;
        [self.chatVC receivedNewChattingMsg:chatMsg];
    }
    else if ([netMessage.flag isEqualToString:kFlagChatR])
    {
        
    }
    else if ([netMessage.flag isEqualToString:kFlagSurrender])
    {
        ANetMessageSurrender *surrenderMsg = (ANetMessageSurrender *)netMessage.message;
        NSString *surrenderType = surrenderMsg.type;
        if ([surrenderType caseInsensitiveCompare:kSurrenderTypeLost] == NSOrderedSame)
        {
            [self endBattleWithResult:kBattleEndResultWon keepConnectionAlive:YES];
        }
        else if ([surrenderType caseInsensitiveCompare:kSurrenderTypeEscape] == NSOrderedSame)
        {
            [self endBattleWithResult:kBattleEndResultWonEnemyEscape keepConnectionAlive:YES];
        }
    }
    else if ([netMessage.flag isEqualToString:kFlagSurrenderR])
    {
        
    }
    else if ([netMessage.flag isEqualToString:kFlagSave])
    {
        AGameRecordManager *recordMgr = [AGameRecordManager sharedInstance];
        recordMgr.actionType = AActionTypeCompetitorAction;
        [self saveCurrentGamingStatus];
    }
    else if ([netMessage.flag isEqualToString:kFlagSaveR])
    {
        
    }
    else if ([netMessage.flag isEqualToString:kFlagLoad])
    {
        ANetMessageLoad *loadMsg = netMessage.message;
        ASavedGameRecord *gameRecord = loadMsg.gameRecord;
        [self loadGameInfoFromGameRecord:gameRecord sentBy:AUserTypeOpponent];
        [self dimissPlacingAircraftGuide];
    }
    else if ([netMessage.flag isEqualToString:kFlagLoadR])
    {
        // netMessage.message is nil here
    }
//    else
//        NSAssert(NO, [AErrorFacade errorMessageFromKnownErrorCode:kECParserCantFindFlag]);
}

- (void)connectionCanceled:(NSError *)errorOrNil
{
    [self.chatVC addNewMessage:ALocalisedString(@"you_have_canceled_connection") toChattingTableWithType:AChattingMsgTypeSystemMsg];
#warning TODO: uncomment after testing
//    [self reset];
}

#pragma mark - setup guide views

- (void)setupAttackPlayGuide
{
    if ([ASetting needsForGuide:AGuideTypeAttackPlayTip])
    {
        _guideVC = [[AGuideViewController alloc] initWithNibName:@"AGuideViewController" bundle:nil];
        _guideVC.type = AGuideTypeAttackPlayTip;
        _guideVC.delegate = self;
        
        CGRect frame = _guideVC.view.frame;
        frame.origin = CGPointMake(0, 10);
        _guideVC.view.frame = frame;
        
        [[AAppDelegate sharedInstance].window addSubview:_guideVC.view];
    }
}

- (void)setupPlacingAircraftGuide
{
    if ([ASetting needsForGuide:AGuideTypePlaceAircraft])
    {
        _guideVC = [[AGuideViewController alloc] initWithNibName:@"AGuideViewController" bundle:nil];
        _guideVC.type = AGuideTypePlaceAircraft;
        _guideVC.delegate = self;
        
        CGRect frame = _guideVC.view.frame;
        frame.origin = CGPointMake(0, 10);
        _guideVC.view.frame = frame;
        
        [[AAppDelegate sharedInstance].window addSubview:_guideVC.view];
    }
}

- (void)dimissPlacingAircraftGuide
{
    if (_guideVC.view)
        [_guideVC.view removeFromSuperview];
}

- (void)setupPlayScreenGuide
{
//    if ([ASetting needsForGuide:AGuideTypePlayScreen])
//    {
        _guideVC = [[AGuideViewController alloc] initWithNibName:@"AGuideViewController" bundle:nil];
        _guideVC.type = AGuideTypePlayScreen;
        _guideVC.delegate = self;
        
        CGRect frame = _guideVC.view.frame;
        frame.origin = CGPointMake(0, 10);
        _guideVC.view.frame = frame;
        
        [[AAppDelegate sharedInstance].window addSubview:_guideVC.view];
//    }
}

// this will be called when user tapped the guide view
- (void)dismissTheGuideView
{
    [_guideVC.view removeFromSuperview];
}

#pragma mark - operation panel

- (AOperationPanelViewController *)getOperationPanelVC
{
    if (!self.opPanelVC)
    {
        self.opPanelVC = [[AOperationPanelViewController alloc] initWithNibName:@"AOperationPanelViewController" bundle:nil];
        self.opPanelVC.operationDelegate = self;
    }
    return self.opPanelVC;
}

- (BOOL)userReadyPlacingAircrafts
{
    if ([_numberOfAircraftPlaced intValue] >= 3)
    {
        _isDonePlacingAircrafts = YES;
        ANetMessageInitial *initialMsg = [[ANetMessageInitial alloc] init];
        
        NSArray *modelAry = self.battleFldVCSelf.aircraftModelAry;
        NSMutableArray *dictionaryModelAry = [NSMutableArray array];
        for (AAircraftModel *model in modelAry)
        {
            [dictionaryModelAry addObject:[model savableDictionary]];
        }
        _selfAircrafts = [NSArray arrayWithArray:dictionaryModelAry];
        
        NSDate *initDate = [NSDate date];
        _gameId = [NSString stringWithFormat:@"%d", (int)[initDate timeIntervalSince1970]];
        
        initialMsg.gameId = _gameId;
        initialMsg.aircrafts = dictionaryModelAry;
        ANetMessage *netMsg = [ANetMessage messageWithFlag:kFlagInitial message:initialMsg];
        
        if (!_userStatus)
            _userStatus = [NSMutableDictionary dictionary];
        NSDate *readyDate = netMsg.timestamp;
        DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(_userStatus, [NSNumber numberWithBool:YES], @"isReady");
        DICT_SET_OBJECT_NULL_IFNOTAVAILABLE(_userStatus, readyDate, @"date");
        
        [self.communicator sendMessage:netMsg];
        
        if (_competitorStatus)// game shall begin
        {
            NSDate *competitorReadyDate = nil;
            DICT_GET_OBJECT(_competitorStatus, competitorReadyDate, @"date");
            if (competitorReadyDate)
            {
                if ([competitorReadyDate timeIntervalSinceDate:readyDate] <= 0)
                {
                    // competitor's turn
                    _whosTurn = AWhosTurnCompetitor;
                }
                else
                {
                    // user's turn (it's very unlikely app goes here)
                    _whosTurn = AWhosTurnUser;
                }
                
                [self startTheGame];
            }
        }
        else // waiting for competitor
        {
            [self.chatVC addNewMessage:ALocalisedString(@"please_wait_for_competitor") toChattingTableWithType:AChattingMsgTypeHelpMsg];
        }
        
        return YES;
    }
    else
    {
        if (self.chatVC)
        {
            [self.chatVC addNewMessage:ALocalisedString(@"add_least_3_aircrafts") toChattingTableWithType:AChattingMsgTypeHelpMsg];
        }
        return NO;
    }
}

- (void)userWantsToExit
{
    _gameRecord = nil;
    if (_competitorStatus && self.communicator != nil)
    {
        ANetMessageSurrender *surrenderMsg = [[ANetMessageSurrender alloc] init];
        surrenderMsg.type = kSurrenderTypeEscape;
        [self.communicator sendMessage:[ANetMessage messageWithFlag:kFlagSurrender message:surrenderMsg]];
        
    }
    else
    {
        
    }
    _isDonePlacingAircrafts = NO;
    [self reset];
}

- (void)userPressedTool1Button
{
//    if (_isGameBegin)
//    {
        // save the game
    AGameRecordManager *recordMgr = [AGameRecordManager sharedInstance];
    recordMgr.actionType = AActionTypeUserAction;
    [self saveCurrentGamingStatus];
//    }
//    else
//        [self.chatVC addNewMessage:ALocalisedString(@"save_only_after_game_begin") toChattingTableWithType:AChattingMsgTypeHelpMsg];
}

- (void)userPressedTool2Button
{
    if (_isGameBegin)
        [self setupPlayScreenGuide];
    else
    {
        if (!_resultVC)
        {
            _resultVC = [[ABattleResultViewController alloc] initWithResultModel:_resultModel];
            _resultVC.delegate = self;
            _resultVC.resultModel = _resultModel;
        }
        
        [[AAppDelegate sharedInstance].navigationController.view addSubview:_resultVC.view];
    }
}

- (void)userPressedAttackButton
{
    if (_isGameBegin && _whosTurn == AWhosTurnUser)
    {
        // this will add the attack record(if selected a target) but not send the attack message
        CGPoint attackPt = [self.battleFldVCEnemy attackedBasedOnPreviousMark];
        
        // check if selected a target
        if (attackPt.x < 0 || attackPt.y < 0)
        {
            if (self.chatVC)
                [self.chatVC addNewMessage:ALocalisedString(@"select_then_attack") toChattingTableWithType:AChattingMsgTypeHelpMsg];
        }
        else // send the net message
        {
            ANetMessageAttack *attackMsg = [[ANetMessageAttack alloc] init];
            attackMsg.row = [NSNumber numberWithFloat:attackPt.x];
            attackMsg.col = [NSNumber numberWithFloat:attackPt.y];
            //        attackMsg.tools =
            
            ANetMessage *netMsg = [ANetMessage messageWithFlag:kFlagAttack message:attackMsg];
            if ([self.communicator sendMessage:netMsg])
            {
                _whosTurn = AWhosTurnCompetitor;
                [self.opPanelVC switchTurn];
            }
        }
    }
}

#pragma mark - battle field view controls

- (ABattleFieldViewController *)getBattleFieldVCFaction:(BattleFieldType)faction
{
    if (faction == BattleFieldEnemy)
    {
        if (!self.battleFldVCEnemy)
        {
            self.battleFldVCEnemy = [[ABattleFieldViewController alloc] initWithNibName:@"ABattleFieldViewController" bundle:nil];
            self.battleFldVCEnemy.faction = faction;
//            self.battleFldVCEnemy.delegate = self;
            self.battleFldVCEnemy.organizerDelegate = self;
        }
        
        return self.battleFldVCEnemy;
    }
    else if (faction == BattleFieldSelf)
    {
        if (!self.battleFldVCSelf)
        {
            self.battleFldVCSelf = [[ABattleFieldViewController alloc] initWithNibName:@"ABattleFieldViewController" bundle:nil];
            self.battleFldVCSelf.faction = faction;
//            self.battleFldVCSelf.delegate = self;
            self.battleFldVCSelf.organizerDelegate = self;
        }
        
        return self.battleFldVCSelf;
    }
    else
        return nil;
}

- (void)aircraftDestroyedAtField:(BattleFieldType)fieldType
{
    if (fieldType == BattleFieldEnemy) 
    {
        if (!_numberOfAircraftDestroyed) 
            _numberOfAircraftDestroyed = [NSNumber numberWithInt:1];
        else
            _numberOfAircraftDestroyed = [NSNumber numberWithInt:([_numberOfAircraftDestroyed intValue] + 1)]; 
        
        NSInteger numberOfAircraftDestroyed = [_numberOfAircraftDestroyed intValue];
        if (numberOfAircraftDestroyed <= 2)
        {
            AUIPopView *popView = [AUIPopView popViewWithText:[NSString stringWithFormat:@"%@\n%d %@", ALocalisedString(@"you_destoryed_aircraft"), 3 - numberOfAircraftDestroyed, ALocalisedString(@"n_to_go")] 
                                                        image:[UIImage imageForBlueRectBackground] 
                                                         size:CGSizeMake(260, 90) 
                                             dissmissDuration:3.5];
            [popView show];
        }
//        else
//            win message will be checked/called when receive surrender Msg
    }
    else if (fieldType == BattleFieldSelf)// if self aircraft has been destroyed
    {
        if (!_numberOfSelfAircraftDestroyed) 
            _numberOfSelfAircraftDestroyed = [NSNumber numberWithInt:1];
        else
            _numberOfSelfAircraftDestroyed = [NSNumber numberWithInt:([_numberOfSelfAircraftDestroyed intValue] + 1)]; 
        
        NSInteger numberOfSelfAircraftDestroyed = [_numberOfSelfAircraftDestroyed intValue];
        if (numberOfSelfAircraftDestroyed <= 2)
        {
            AUIPopView *popView = [AUIPopView popViewWithText:[NSString stringWithFormat:@"%@\n%d %@", ALocalisedString(@"your_aircraft_destoryed"), 3 - numberOfSelfAircraftDestroyed, ALocalisedString(@"n_left")] 
                                                        image:[UIImage imageForOrangeRectBackground] 
                                                         size:CGSizeMake(260, 90) 
                                             dissmissDuration:3.5];
            [popView show];
        }
        else
        {
            ANetMessageSurrender *surrenderMsg = [[ANetMessageSurrender alloc] init];
            surrenderMsg.type = kSurrenderTypeLost;
            ANetMessage *netMessage = [ANetMessage messageWithFlag:kFlagSurrender message:surrenderMsg];
            [self.communicator sendMessage:netMessage];
            [self endBattleWithResult:kBattleEndResultLost keepConnectionAlive:YES];
        }
    }
    else if (fieldType == BattleFieldNone)
    {
        // here would be an error
    }
}

- (void)aircraftAdded
{
    if (!_numberOfAircraftPlaced)
        _numberOfAircraftPlaced = [NSNumber numberWithInt:1];
    else
        _numberOfAircraftPlaced = [NSNumber numberWithInt:[_numberOfAircraftPlaced intValue] + 1];
    
    self.opPanelVC.readyButton.enabled = [self checkReadyForPlacingAircrafts];
}

- (void)aircraftRemoved
{
    if (!_numberOfAircraftPlaced)
        _numberOfAircraftPlaced = [NSNumber numberWithInt:0];
    else
        _numberOfAircraftPlaced = [NSNumber numberWithInt:[_numberOfAircraftPlaced intValue] - 1];
    
    self.opPanelVC.readyButton.enabled = [self checkReadyForPlacingAircrafts];
}

- (BOOL)checkReadyForPlacingAircrafts
{
    if (_numberOfAircraftPlaced)
    {
        return [_numberOfAircraftPlaced intValue] >= 3 ? YES : NO;
    }
    else
        return NO;
}

- (void)attackPositionMarked:(BOOL)onPreviousAttackedPos;
{
    self.opPanelVC.attackButton.enabled = onPreviousAttackedPos ? NO : YES;
}

- (void)attackPositionUnmarked
{
    self.opPanelVC.attackButton.enabled = NO;
}

/*!
 @discussion this method will be called when user drag aircraft off the field and try to removed the aircraft, return YES to allow this operation, otherwize aircraft won't be removed.
 */
- (BOOL)userWantsToRemoveAircraft:(AAircraftModel *)aircraft
{
    if (_isGameBegin)
        return NO;
    else
        return YES;
}

- (BOOL)userWantsToAddAircraft:(AAircraftModel *)aircraft
{
    if (_numberOfAircraftPlaced)
    {
        return [_numberOfAircraftPlaced intValue] >= 3 ? NO : YES;
    }
    else
        return YES;
}

#pragma mark - chatting view controls

- (AChattingViewController *)getChatVC
{
    if (!self.chatVC)
    {
        self.chatVC = [[AChattingViewController alloc] initWithNibName:@"AChattingViewController" bundle:nil];
        self.chatVC.delegate = self;
    }
    
    return self.chatVC;
}

/*
 - (void)setNickNameForUser:(NSString *)userName andCompetitor:(NSString *)competitorName;
 - (void)resignTxtFldFirstResponder;
 - (void)receivedNewChattingMsg:(ANetMessageChat *)message;
 */

#pragma mark - chat view protocol/delegate

- (void)userWantsToSendChatMsg:(ANetMessageChat *)message
{
    ANetMessage *msg = [ANetMessage messageWithFlag:kFlagChat message:message];
    if (self.communicator)
        [self.communicator sendMessage:msg];
    else
        [AErrorFacade errorWithDomain:kErrorDomainOrganizer knownCode:kECOrganizerCommunicatorNotFoundOrEnpty];
}

- (void)userInputCheatCode:(NSString *)cheatCode
{
#warning TODO: handle the cheat code
}

@end
