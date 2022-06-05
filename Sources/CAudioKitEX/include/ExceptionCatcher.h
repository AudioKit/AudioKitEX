// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

//  Inspired by https://github.com/RedRoma/SwiftExceptionCatcher

#pragma once

#import <Foundation/Foundation.h>

void ExceptionCatcherOperation(void (^ _Nonnull tryBlock)(void),
                               void (^ _Nullable catchBlock)(NSException * _Nonnull));


