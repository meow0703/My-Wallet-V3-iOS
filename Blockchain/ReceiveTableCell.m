//
//  ReceiveTableCell.m
//  Blockchain
//
//  Created by Ben Reeves on 19/03/2012.
//  Copyright (c) 2012 Qkos Services Ltd. All rights reserved.
//

#import "ReceiveTableCell.h"

@implementation ReceiveTableCell

@synthesize balanceLabel;
@synthesize labelLabel;
@synthesize addressLabel;
@synthesize watchLabel;
@synthesize balanceButton;

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.balanceLabel.adjustsFontSizeToFitWidth = YES;
    self.watchLabel.adjustsFontSizeToFitWidth = YES;
    self.watchLabel.text = BC_STRING_WATCH_ONLY;
}

@end
