//
//  main.m
//  Houdini
//
//  Created by Daniel Westendorf on 2/20/12.
//  Copyright (c) 2012 Daniel Westendorf. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MacRuby/MacRuby.h>

int main(int argc, char *argv[])
{
    return macruby_main("rb_main.rb", argc, argv);
}
