//
//  HFHexTextRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFRepresenterHexTextView.h>
#import <HexFiend/HFHexPasteboardOwner.h>

@implementation HFHexTextRepresenter

/* No extra NSCoder support needed */

- (Class)_textViewClass {
    return [HFRepresenterHexTextView class];
}

- (void)initializeView {
    [super initializeView];
    [[self view] setBytesBetweenVerticalGuides:4];
    unpartneredLastNybble = UCHAR_MAX;
    omittedNybbleLocation = ULLONG_MAX;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 0);
}

- (void)_clearOmittedNybble {
    unpartneredLastNybble = UCHAR_MAX;
    omittedNybbleLocation = ULLONG_MAX;
}

- (BOOL)_insertionShouldDeleteLastNybble {
    /* Either both the omittedNybbleLocation and unpartneredLastNybble are invalid (set to their respective maxima), or neither are */
    HFASSERT((omittedNybbleLocation == ULLONG_MAX) == (unpartneredLastNybble == UCHAR_MAX));
    /* We should delete the last nybble if our omittedNybbleLocation is the point where we would insert */
    BOOL result = NO;
    if (omittedNybbleLocation != ULLONG_MAX) {
        HFController *controller = [self controller];
        NSArray *selectedRanges = [controller selectedContentsRanges];
        if ([selectedRanges count] == 1) {
            HFRange selectedRange = [selectedRanges[0] HFRange];
            result = (selectedRange.length == 0 && selectedRange.location > 0 && selectedRange.location - 1 == omittedNybbleLocation);
        }
    }
    return result;
}

- (BOOL)_canInsertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    return [text rangeOfCharacterFromSet:characterSet].location != NSNotFound;
}

- (void)insertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    if (! [self _canInsertText:text]) {
        /* The user typed invalid data, and we can ignore it */
        return;
    }
    
    BOOL shouldReplacePriorByte = [self _insertionShouldDeleteLastNybble];
    if (shouldReplacePriorByte) {
        HFASSERT(unpartneredLastNybble < 16);
        /* Prepend unpartneredLastNybble as a nybble */
        text = [NSString stringWithFormat:@"%1X%@", unpartneredLastNybble, text];
    }
    BOOL isMissingLastNybble;
    NSData *data = HFDataFromHexString(text, &isMissingLastNybble);
    HFASSERT([data length] > 0);
    HFASSERT(shouldReplacePriorByte != isMissingLastNybble);
    HFController *controller = [self controller];
    BOOL success = [controller insertData:data replacingPreviousBytes: (shouldReplacePriorByte ? 1 : 0) allowUndoCoalescing:YES];
    if (isMissingLastNybble && success) {
        HFASSERT([data length] > 0);
        HFASSERT(unpartneredLastNybble == UCHAR_MAX);
        [data getBytes:&unpartneredLastNybble range:NSMakeRange([data length] - 1, 1)];
        NSArray *selectedRanges = [controller selectedContentsRanges];
        HFASSERT([selectedRanges count] >= 1);
        HFRange selectedRange = [selectedRanges[0] HFRange];
        HFASSERT(selectedRange.location > 0);
        omittedNybbleLocation = HFSubtract(selectedRange.location, 1);
    }
    else {
        [self _clearOmittedNybble];
    }
}

- (NSData *)dataFromPasteboardString:(NSString *)string {
    REQUIRE_NOT_NULL(string);
    return HFDataFromHexString(string, NULL);
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & HFControllerHideNullBytes) {
        [[self view] setHidesNullBytes:[[self controller] shouldHideNullBytes]];
    }
    [super controllerDidChange:bits];
    if (bits & (HFControllerContentValue | HFControllerContentLength | HFControllerSelectedRanges)) {
        [self _clearOmittedNybble];
    }
}

- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb {
    REQUIRE_NOT_NULL(pb);
    HFByteArray *selection = [[self controller] byteArrayForSelectedContentsRanges];
    HFASSERT(selection != NULL);
    if ([selection length] == 0) {
        NSBeep();
    } else {
        HFHexPasteboardOwner *owner = [HFHexPasteboardOwner ownPasteboard:pb forByteArray:selection withTypes:@[HFPrivateByteArrayPboardType, NSStringPboardType]];
        [owner setBytesPerLine:[self bytesPerLine]];
        owner.bytesPerColumn = self.bytesPerColumn;
    }
}

@end
