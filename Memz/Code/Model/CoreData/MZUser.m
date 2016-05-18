//
//  MZUser.m
//  
//
//  Created by Bastien Falcou on 5/1/16.
//
//

#import "MZUser.h"
#import "MZQuiz.h"
#import "MZWord.h"
#import "NSManagedObject+MemzCoreData.h"

NSString * const MZUserDidAuthenticateNotification = @"MZUserDidAuthenticateNotification";

@implementation MZUser

+ (MZUser *)currentUser {
	NSArray *users = [MZUser allObjects];
	NSAssert(users.count <= 1, @"there can't be several current users at the same time");
	if (users.count == 0) {
		return nil;
	}
	return users.firstObject;
}

+ (MZUser *)signUpUserKnownLanguage:(MZLanguage)knownLanguage
												newLanguage:(MZLanguage)newLanguage {
	MZUser *user = [MZUser newInstance];
	user.knownLanguage = @(knownLanguage);
	user.newLanguage = @(newLanguage);

	[[NSNotificationCenter defaultCenter] postNotificationName:MZUserDidAuthenticateNotification object:user];
	return user;
}

- (MZWord *)addWord:(NSString *)word translations:(NSArray<NSString *> *)translations inContext:(NSManagedObjectContext *)context {
	return [MZWord addWord:word
							inLanguage:self.newLanguage.integerValue
						translations:translations
							toLanguage:self.knownLanguage.integerValue
								 forUser:self
							 inContext:context];
}

@end
