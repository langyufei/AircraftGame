//
//  ABattleFieldModel.m
//  Aircraft
//
//  Created by Yufei Lang on 1/8/13.
//  Copyright (c) 2013 Yufei Lang. All rights reserved.
//

#import "ABattleFieldModel.h"

@interface ABattleFieldModel()



@end

@implementation ABattleFieldModel

@synthesize type = _type;
@synthesize attackPoint = _attackPoint;
@synthesize attackRecord = _attackRecord;
@synthesize aircraftModelAry = _aircraftModelAry;

- (id)init
{
    if (self = [super init])
    {
        _type = BattleFieldNone;
        _attackPoint = CGPointMake(-1, -1);
        
        for (int i = 0; i < 10; i++)
            for (int j = 0; j < 10; j++)
                _battleFieldGrid[i][j] = AircraftNone;
        
    }
    return self;
}

- (CGPoint)lastAttackPoint
{
    if ([self.attackRecord count] > 0)
    {
        NSArray *lastPt = [self.attackRecord lastObject];
        NSNumber *row = [lastPt objectAtIndex:0];
        NSNumber *col = [lastPt objectAtIndex:1];
        return CGPointMake([row floatValue], [col floatValue]);
    }
    else
    {
        return CGPointMake(-1, -1);
    }
}

- (NSInteger)numberOfHits
{
    if (_attackRecord)
    {
        if (_attackRecord.count > 0)
        {
            if (_aircraftModelAry)
            {
                if (_aircraftModelAry.count > 0)
                {
                    NSInteger hitNumber = 0;
                    for (NSArray *attackPtAry in _attackRecord)
                    {
                        CGPoint attackPt = CGPointMake([((NSNumber *)[attackPtAry objectAtIndex:0]) intValue],
                                                       [((NSNumber *)[attackPtAry objectAtIndex:1]) intValue]);
                        
                        if (!([[self attackResultInGridAtPoint:attackPt] caseInsensitiveCompare:kAttackRMiss] == NSOrderedSame))
                            hitNumber ++;
                    }
                    
                    return hitNumber;
                }
                else
                    return 0;
            }
            else
                return 0;
        }
        else
            return 0;
    }
    else
        return 0;
}

- (NSInteger)numberOfAircraftDestroyed
{
    if (_attackRecord)
    {
        if (_attackRecord.count > 0)
        {
            if (_aircraftModelAry)
            {
                if (_aircraftModelAry.count > 0)
                {
                    NSInteger number = 0;
                    for (NSArray *attackPtAry in _attackRecord)
                    {
                        CGPoint attackPt = CGPointMake([((NSNumber *)[attackPtAry objectAtIndex:0]) intValue],
                                                       [((NSNumber *)[attackPtAry objectAtIndex:1]) intValue]);
                        
                        if ([[self attackResultInGridAtPoint:attackPt] caseInsensitiveCompare:kAttackRDestroy] == NSOrderedSame)
                            number ++;
                    }
                    
                    return number;
                }
                else
                    return 0;
            }
            else
                return 0;
        }
        else
            return 0;
    }
    else
        return 0;
}

- (BOOL)addAttackRecordPoint//:(CGPoint)attackPoint
{
//    NSAssert(, @"[error]: set 'attackPoint' before calling method 'addAttackRecordPoint'");
    
    // "attackPoint" has not been set yet.
    if (_attackPoint.x == -1 || _attackPoint.y == -1)
    {
        return NO;
    }
    else
    {
        NSArray *pointArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:_attackPoint.x],
                               [NSNumber numberWithInt:_attackPoint.y], nil];
        
        if (!self.attackRecord)
            self.attackRecord = [NSMutableArray arrayWithObject:pointArray];
        else
            [self.attackRecord addObject:pointArray];
        
        _attackPoint = CGPointMake(-1, -1);
        
        return YES;
    }
}

- (AircraftPart)attackResultPartInGridAtPoint:(CGPoint)point
{
    return _battleFieldGrid[(int)point.y][(int)point.x];
}

- (NSString *)attackResultInGridAtPoint:(CGPoint)point
{
    AircraftPart part = _battleFieldGrid[(int)point.y][(int)point.x];
    switch (part)
    {
        case AircraftNone:
        {
            return kAttackRMiss;
        }
            break;
        case AircraftHead:
        {
            return kAttackRDestroy;
        }
            break;
        case AircraftBody:
        {
            return kAttackRHit;
        }
            break;
            
        default:
            break;
    }
}

- (void)addAircraft:(AAircraftModel *)aircraft
{
    if (_aircraftModelAry)
    {
        [_aircraftModelAry addObject:aircraft];
        
        [self fillGridForAircraft:aircraft];
    }
    else
    {
        _aircraftModelAry = [NSMutableArray arrayWithObject:aircraft];
        
        [self fillGridForAircraft:aircraft];
    }
}

- (void)removeAircraft:(AAircraftModel *)aircraft
{
    if (_aircraftModelAry)
    {
        if ([_aircraftModelAry containsObject:aircraft])
        {
            [_aircraftModelAry removeObject:aircraft];
            
            [self clearGridForAircraft:aircraft];
        }
    }
}

- (void)clearGridForAircraft:(AAircraftModel *)aircraft
{
    // remove from gird
    int offsetY = aircraft.orginPos.x;
    int offsetX = aircraft.orginPos.y;
    
    for (int row = offsetX, aRow = 0; row < offsetX + 5; row++, aRow++)
        for (int col = offsetY, aCol = 0; col < offsetY + 5; col++, aCol++)
        {
            if ([aircraft elementAtRow:aRow col:aCol] != AircraftNone)
                _battleFieldGrid[row][col] = AircraftNone;
        }
}

- (void)fillGridForAircraft:(AAircraftModel *)aircraft
{
    // add to gird
    int offsetY = aircraft.orginPos.x;
    int offsetX = aircraft.orginPos.y;
    
    // scan 4*5 if Up or Down, otherwise 5*4
    if (aircraft.direction == AircraftDirectionUp || aircraft.direction == AircraftDirectionDown ? YES : NO)
    {
        for (int row = offsetX, aRow = 0; row < offsetX + 4; row++, aRow++)
            for (int col = offsetY, aCol = 0; col < offsetY + 5; col++, aCol++)
            {
                if ([aircraft elementAtRow:aRow col:aCol] != AircraftNone) {
                    _battleFieldGrid[row][col] = [aircraft elementAtRow:aRow col:aCol];
                }
            }
    }
    else
    {
        for (int row = offsetX, aRow = 0; row < offsetX + 5; row++, aRow++)
            for (int col = offsetY, aCol = 0; col < offsetY + 4; col++, aCol++)
            {
                if ([aircraft elementAtRow:aRow col:aCol] != AircraftNone) {
                    _battleFieldGrid[row][col] = [aircraft elementAtRow:aRow col:aCol];
                }
            }
    }
}

/*!
 @discussion check if the point was previous attacked
 */
- (BOOL)checkIfAttackedAtPoint:(CGPoint)point
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF[0] = %d AND SELF[1] = %d", (int)point.x, (int)point.y];
    NSArray *resAry = [self.attackRecord filteredArrayUsingPredicate:predicate];
    return resAry.count > 0 ? YES : NO;
}

- (BOOL)checkPositionForAircraft:(AAircraftModel *)aircraft
{
    if (_aircraftModelAry)
    {
        if (_aircraftModelAry.count != 0)
        {
            int offsetY = aircraft.orginPos.x;
            int offsetX = aircraft.orginPos.y;
            
            for (int row = offsetX, aRow = 0; row < offsetX + 5; row++, aRow++)
            {
                for (int col = offsetY, aCol = 0; col < offsetY + 5; col++, aCol++)
                {
                    if ([aircraft elementAtRow:aRow col:aCol] != AircraftNone &&
                        _battleFieldGrid[row][col] != AircraftNone)
                        return NO;
                }
            }
            return YES;
        }
        else
        {
            return YES;
        }
    }
    else
    {
        _aircraftModelAry = [NSMutableArray array];
        return YES;
    }
}

@end
