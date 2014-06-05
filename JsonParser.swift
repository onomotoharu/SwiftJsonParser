/*
 * Copyright (c) 2014 Akihiro Ito @ Project W Inc.
 *
 * This software is released under the MIT License.
 *
 * http://opensource.org/licenses/mit-license.php
 */

import Foundation

class JsonParser {
    
    init() {
        return;
    }
    
    func parse(text: String) -> JsonEntity? {
        var entities: Array<TokenOrEntity> = Array<TokenOrEntity>();
        var hasError: Bool = false;
        var tokenizer: Tokenizer = Tokenizer(text: text);
        var type: Int = 0;
        var token: String = "";
        do {
            var entity: TokenOrEntity = TokenOrEntity();
            (type, token) = tokenizer.tokenize();
            if type == tokenizer.TOKEN_EOF {
                break;
            } else if type == tokenizer.TOKEN_INVALID {
                hasError = true;
                break;
            } else if type == tokenizer.TOKEN_SPACE {
                continue;
            } else if type == tokenizer.TOKEN_DECIMAL {
                entity.type = entity.JSON_INTEGER;
                entity.intValue = token.toInt();
                entities.insert(entity, atIndex: 0);
            } else if type == tokenizer.TOKEN_STRING {
                entity.type = entity.JSON_STRING;
                entity.string = decodeString(token);
                entities.insert(entity, atIndex: 0);
            } else if type == tokenizer.TOKEN_TRUE {
                entity.type = entity.JSON_BOOLEAN;
                entity.boolValue = true;
                entities.insert(entity, atIndex: 0);
            } else if type == tokenizer.TOKEN_FALSE {
                entity.type = entity.JSON_BOOLEAN;
                entity.boolValue = false;
                entities.insert(entity, atIndex: 0);
            } else if type == tokenizer.TOKEN_NULL {
                entity.type = entity.JSON_NULL;
                entities.insert(entity, atIndex: 0);
            } else if type == tokenizer.TOKEN_SYMBOL {
                entity.type = entity.JSON_TOKEN;
                entity.string = token;
                entities.insert(entity, atIndex: 0);
            }
            if entity.type == entity.JSON_TOKEN && "}" == entity.string {
                var dict: Dictionary<String, JsonEntity> = Dictionary<String, JsonEntity>();
                while !hasError && entities.count > 0 {
                    var e0: TokenOrEntity = entities[0];
                    if e0.type == e0.JSON_TOKEN {
                        if e0.string == "{" {
                            entities.removeAtIndex(0);
                            var e: TokenOrEntity = TokenOrEntity();
                            e.type = e.JSON_OBJECT;
                            e.object = dict;
                            entities.insert(e, atIndex: 0);
                            break;
                        } else if e0.string == "," || e0.string == "}" {
                            if entities.count >= 4 {
                                var e1: TokenOrEntity = entities[1];
                                var e2: TokenOrEntity = entities[2];
                                var e3: TokenOrEntity = entities[3];
                                if e2.type == e2.JSON_TOKEN && e2.string == ":" && e3.type == e3.JSON_STRING {
                                    dict[e3.string!] = e1;
                                    entities.removeAtIndex(0);
                                    entities.removeAtIndex(0);
                                    entities.removeAtIndex(0);
                                    entities.removeAtIndex(0);
                                    continue;
                                }
                            }
                        }
                    }
                    hasError = true;
                }
            } else if entity.type == entity.JSON_TOKEN && "]" == entity.string {
                var array: Array<TokenOrEntity> = Array<TokenOrEntity>();
                while !hasError && entities.count > 0 {
                    var e0: TokenOrEntity = entities[0];
                    if e0.type == e0.JSON_TOKEN {
                        if e0.string == "[" {
                            entities.removeAtIndex(0);
                            var e: TokenOrEntity = TokenOrEntity();
                            e.type = e.JSON_ARRAY;
                            e.array = array;
                            entities.insert(e, atIndex: 0);
                            break;
                        } else if e0.string == "," || e0.string == "]" {
                            if entities.count >= 2 {
                                var e1: TokenOrEntity = entities[1];
                                array.insert(e1, atIndex:0);
                                entities.removeAtIndex(0);
                                entities.removeAtIndex(0);
                                continue;
                            }
                        }
                    }
                    hasError = true;
                }
            }
        } while !hasError;
        if entities.count != 1 {
            hasError = true;
        }
        return !hasError ? entities[0] : nil;
    }
    
    // TODO: unescape
    func decodeString(token: String) -> String {
        var length: Int = 0;
        for char in token {
            length++;
        }
        var result: String = "";
        var i: Int = 0;
        for char in token {
            if 0 < i && i < length - 1 {
                result += char;
            }
            i++;
        }
        return result;
    }
    
}

class JsonEntity {
    
    let JSON_OBJECT = 1;
    let JSON_ARRAY = 2;
    let JSON_BOOLEAN = 3;
    let JSON_NULL = 4;
    let JSON_FLOAT = 5;
    let JSON_INTEGER = 6;
    let JSON_STRING = 7;
    
    var type: Int;
    var object: Dictionary<String, JsonEntity>?;
    var array: Array<JsonEntity>?;
    var boolValue: Bool?;
    var floatValue: Double?;
    var intValue: Int?;
    var string: String?;
    
    init() {
        type = JSON_NULL;
        object = nil;
        array = nil;
        boolValue = nil;
        floatValue = nil;
        intValue = nil;
        string = nil;
        return;
    }
    
}

class TokenOrEntity: JsonEntity {

    let JSON_TOKEN = 101;

    init() {
        super.init();
        return;
    }
    
}


class Tokenizer {
   
    let TOKEN_SPACE = 1;
    let TOKEN_FLOAT = 2;
    let TOKEN_DECIMAL = 3;
    let TOKEN_HEXADEC = 4;
    let TOKEN_TRUE = 5;
    let TOKEN_FALSE = 6;
    let TOKEN_NULL = 7;
    let TOKEN_STRING = 8;
    let TOKEN_SYMBOL = 9;
    let TOKEN_EOF = 10;
    let TOKEN_INVALID = 11;
    
    let CHAR_SPACE = 1;
    let CHAR_SIGN = 2;
    let CHAR_DIGIT = 3;
    let CHAR_HEXDIGIT = 4;
    let CHAR_SYMBOL = 5;
    let CHAR_OTHER = 6;
    
    var chars: Array<Character>;
    var length: Int;
    var idx: Int;
    var hasError: Bool;
    
    init(text: String) {
        chars = Array<Character>();
        length = 0;
        for char in text {
            chars.insert(char, atIndex: length);
            length++;
        }
        idx = 0;
        hasError = false;
    }
    
    func tokenize() -> (Int, String) {
        var type: Int = TOKEN_INVALID;
        var token: String = "";
        if hasError {
            // nop;
        } else if idx >= length {
            type = TOKEN_EOF;
        } else {
            var headType: Int = judgeCharacterType(chars[idx]);
            if headType == CHAR_SPACE {
                type = TOKEN_SPACE;
                do {
                    if judgeCharacterType(chars[idx]) == CHAR_SPACE {
                        token += chars[idx++];
                    } else {
                         break;
                    }
                } while idx < length;
            } else if headType == CHAR_SYMBOL {
                type = TOKEN_SYMBOL;
                token += chars[idx];
                idx++;
            } else if headType == CHAR_SIGN || headType == CHAR_DIGIT {
                token += chars[idx];
                do {
                    idx++;
                    if judgeCharacterType(chars[idx]) == CHAR_DIGIT {
                        token += chars[idx];
                    } else {
                       break;
                    }
                } while idx < length;
                if token == "+" || token == "-" {
                    hasError = true;
                } else {
                    type = TOKEN_DECIMAL;
                }
            } else if chars[idx] == "t"{
                if (length - idx >= 4) {
                    token += chars[idx++];
                    token += chars[idx++];
                    token += chars[idx++];
                    token += chars[idx++];
                }
                if token == "true" {
                    type = TOKEN_TRUE;
                } else {
                    hasError = true;
                }
            } else if chars[idx] == "f" {
                if (length - idx >= 5) {
                    token += chars[idx++];
                    token += chars[idx++];
                    token += chars[idx++];
                    token += chars[idx++];
                    token += chars[idx++];
                }
                if token == "false" {
                    type = TOKEN_FALSE;
                } else {
                    hasError = true;
                }
           } else if chars[idx] == "n" {
                if (length - idx >= 4) {
                    token += chars[idx++];
                    token += chars[idx++];
                    token += chars[idx++];
                    token += chars[idx++];
                }
                if token == "null" {
                    type = TOKEN_NULL;
                } else {
                    hasError = true;
                }
           } else if chars[idx] == "\"" {
                if length - idx > 1 {
                    token += chars[idx++];
                    while idx < length && chars[idx] != "\"" {
                        if chars[idx] != "\\" {
                            token += chars[idx++];
                        } else {
                            token += chars[idx++];
                            var flag: Bool = false;
                            for char in "\"\\bfnrt" {
                                if chars[idx] == char {
                                    flag = true;
                                    break;
                                }
                            }
                            if flag {
                                token += chars[idx++];
                            } else if length - idx >= 4 {
                                for i in 0..3 {
                                    var t: Int = judgeCharacterType(chars[idx]);
                                    if t == CHAR_DIGIT || t == CHAR_HEXDIGIT {
                                        token += chars[idx++];
                                    } else {
                                        hasError = true;
                                    }
                                }
                            } else {
                                hasError = true;
                            }
                        }
                    }
                    if chars[idx] == "\"" {
                        token += chars[idx++];
                        type = TOKEN_STRING;
                   }
                } else {
                    hasError = true;
                }
            }
        }
        return (type, token);
    }
    
    func judgeCharacterType(char: Character) -> Int {
        var ret: Int = CHAR_OTHER;
        switch char {
        case " ", "\t", "\n", "\r":
            ret = CHAR_SPACE;
        case "+", "-":
            ret = CHAR_SIGN;
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            ret = CHAR_DIGIT;
        case "a", "b", "c", "d", "e", "f", "A", "B", "C", "D", "E", "F":
            ret = CHAR_HEXDIGIT;
        case "{", "}", "[", "]", ":", ",":
            ret = CHAR_SYMBOL;
        default:
            ret = CHAR_OTHER;
        }
        return ret;
    }
    
}
