//
//  _DDFunctionExpression.m
//  DDMathParser
//
//  Created by Dave DeLong on 11/18/10.
//  Copyright 2010 Home. All rights reserved.
//

#import "DDMathParser.h"
#import "_DDFunctionExpression.h"
#import "DDMathEvaluator.h"
#import "DDMathEvaluator+Private.h"
#import "_DDNumberExpression.h"
#import "_DDVariableExpression.h"
#import "DDMathParserMacros.h"

@interface DDExpression ()

- (void)_setParentExpression:(DDExpression *)parent;

@end

@implementation _DDFunctionExpression {
	NSString *_function;
	NSArray *_arguments;
}

- (id)initWithFunction:(NSString *)f arguments:(NSArray *)a error:(NSError **)error {
	self = [super init];
	if (self) {
		for (id arg in a) {
			if ([arg isKindOfClass:[DDExpression class]] == NO) {
				if (error != nil) {
                    *error = ERR(DDErrorCodeInvalidArgument, @"function arguments must be DDExpression objects");
				}
				return nil;
			}
		}
		
		_function = [f copy];
		_arguments = [a copy];
        for (DDExpression *argument in _arguments) {
            [argument _setParentExpression:self];
        }
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSString *f = [aDecoder decodeObjectForKey:@"function"];
    NSArray *a = [aDecoder decodeObjectForKey:@"arguments"];
    return [self initWithFunction:f arguments:a error:NULL];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:[self function] forKey:@"function"];
    [aCoder encodeObject:[self arguments] forKey:@"arguments"];
}

- (id)copyWithZone:(NSZone *)zone {
    NSMutableArray *newArguments = [NSMutableArray array];
    for (id<NSCopying> arg in [self arguments]) {
        [newArguments addObject:[arg copyWithZone:zone]];
    }
    
    return [[[self class] alloc] initWithFunction:[self function] arguments:newArguments error:nil];
}

- (DDExpressionType)expressionType { return DDExpressionTypeFunction; }

- (NSString *)function { return [_function lowercaseString]; }
- (NSArray *)arguments { return _arguments; }

- (DDExpression *)simplifiedExpressionWithEvaluator:(DDMathEvaluator *)evaluator error:(NSError **)error {
	BOOL canSimplify = YES;
    
    //TODO:
    DDExpression *f = self.arguments[0];
    DDExpression *s = self.arguments[1];
    if ([self.function isEqualToString:DDOperatorMultiply]) {
        //simplified 0*x && 1*x
        if (f.expressionType == DDExpressionTypeNumber && [[f number] intValue] == 0) {
            return [DDExpression numberExpressionWithNumber:@0];
        }
        
        if (s.expressionType == DDExpressionTypeNumber && [[s number] intValue] == 0) {
            return [DDExpression numberExpressionWithNumber:@0];
        }
        
        if (f.expressionType == DDExpressionTypeNumber && [[f number] intValue] == 1) {
            return [s simplifiedExpressionWithEvaluator:evaluator error:error];
        }
        
        if (s.expressionType == DDExpressionTypeNumber && [[s number] intValue] == 1) {
            return [f simplifiedExpressionWithEvaluator:evaluator error:error];
        }
    }else if ([self.function isEqualToString:DDOperatorAdd]) {
        if (f.expressionType == DDExpressionTypeNumber && [[f number] intValue] == 0) {
            return [s simplifiedExpressionWithEvaluator:evaluator error:error];
        }
        
        if (s.expressionType == DDExpressionTypeNumber && [[s number] intValue] == 0) {
            return [f simplifiedExpressionWithEvaluator:evaluator error:error];
        }
    }else if ([self.function isEqualToString:DDOperatorMinus]) {
        if (s.expressionType == DDExpressionTypeNumber && [[s number] intValue] == 0) {
            return [f simplifiedExpressionWithEvaluator:evaluator error:error];
        }
    }else if ([self.function isEqualToString:DDOperatorDivide]) {
        if (f.expressionType == DDExpressionTypeNumber && [[f number] intValue] == 0) {
            return [DDExpression numberExpressionWithNumber:@0];
        }
    }else if ([self.function isEqualToString:DDOperatorPower]) {
        if (s.expressionType == DDExpressionTypeNumber && [[s number] intValue] == 1) {
            return f;
        }
        if (s.expressionType == DDExpressionTypeNumber && [[s number] intValue] == 0) {
            return [DDExpression numberExpressionWithNumber:@(1)];
        }
    }
    
    BOOL shouldResimplify = NO;
    NSMutableArray *newSubexpressions = [NSMutableArray array];
	for (DDExpression * e in [self arguments]) {
		DDExpression * a = [e simplifiedExpressionWithEvaluator:evaluator error:error];
        if (e.expressionType != DDExpressionTypeNumber && a.expressionType == DDExpressionTypeNumber) {
            shouldResimplify = YES;
        }
		if (!a) { return nil; }
        canSimplify &= [a expressionType] == DDExpressionTypeNumber;
        [newSubexpressions addObject:a];
	}
	
    DDExpression *simpleFunc = [DDExpression functionExpressionWithFunction:[self function] arguments:newSubexpressions error:error];
    if (shouldResimplify) {
        simpleFunc = [simpleFunc simplifiedExpressionWithEvaluator:evaluator error:nil];
    }
	if (canSimplify) {
		if (evaluator == nil) { evaluator = [DDMathEvaluator defaultMathEvaluator]; }
		
        id result = [evaluator evaluateExpression:simpleFunc withSubstitutions:nil error:error];
		
		if ([result isKindOfClass:[_DDNumberExpression class]]) {
			return result;
		} else if ([result isKindOfClass:[NSNumber class]]) {
			return [DDExpression numberExpressionWithNumber:result];
		}		
	}
	
    return simpleFunc;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@(%@)", [self function], [[[self arguments] valueForKey:@"description"] componentsJoinedByString:@","]];
}

@end
