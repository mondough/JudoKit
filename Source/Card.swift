//
//  Card.swift
//  JudoKit
//
//  Created by Hamon Riazy on 13/08/2015.
//  Copyright © 2015 Judo Payments. All rights reserved.
//

import Foundation
import Judo


let VISAPattern         = "XXXX XXXX XXXX XXXX"
let AMEXPattern         = "XXXX XXXXXX XXXXX"
let CUPPattern          = "XXXXXX XXXXXXXXXXXXX"
let DinersClubPattern   = "XXXX XXXXXX XXXX"


// these should be computed once and then referenced - O(n)
let masterCardPrefixes          = ([Int](2221...2720)).map({ String($0) }) + ([Int](51...55)).map { String($0) }
let maestroPrefixes             = ([Int](56...69)).map({ String($0) }) + ["50"]
let dinersClubPrefixes          = ([Int](300...305)).map({ String($0) }) + ["36", "38", "39", "309"]
let instaPaymentPrefixes        = ([Int](637...639)).map({ String($0) })
let JCBPrefixes                 = ([Int](3528...3589)).map({ String($0) })

// expression was too complex to be executed in one line 😩😭💥
let discoverPrefixes: [String]  = {
    let discover = ([Int](644...649)).map({ String($0) }) + ([Int](622126...622925)).map({ String($0) })
    return discover + ["65", "6011"]
    }()


public extension String {
    
    
    /**
    returns a string that matches the format of the number on the card itself based on the spacing pattern
    
    - Returns: a String with correct spacing for a credit card number
    */
    func cardPresentationString() throws -> String? {
        
        var strippedSelf = self.stringByReplacingOccurrencesOfString(" ", withString: "")

        if strippedSelf.characters.count == 0 {
            return nil
        } else if strippedSelf.characters.count > 19 {
            throw JudoError.Unknown
        }
        
        if strippedSelf.cardNetwork() == .Unknown {
            return strippedSelf
        }
        
        var patternString: String? = nil
        
        switch self.cardNetwork() {
        case .Visa(.Debit), .Visa(.Credit), .Visa(.Unknown), .MasterCard(.Debit), .MasterCard(.Credit), .MasterCard(.Unknown), .Dankort, .JCB, .InstaPayment, .Discover:
            if strippedSelf.characters.count <= 16 {
                patternString = VISAPattern
            } else {
                throw JudoError.Unknown
            }
            break
        case .AMEX:
            if strippedSelf.characters.count <= 15 {
                patternString = AMEXPattern
            } else {
                throw JudoError.Unknown
            }
            break
        case .ChinaUnionPay, .InterPayment:
            if strippedSelf.characters.count <= 16 {
                patternString = VISAPattern
            } else if strippedSelf.characters.count == 19 {
                patternString = CUPPattern
            } else {
                throw JudoError.Unknown
            }
            break;
        case .DinersClub:
            if strippedSelf.characters.count <= 14 {
                patternString = DinersClubPattern
            } else if strippedSelf.characters.count <= 16 {
                patternString = VISAPattern
            } else {
                throw JudoError.Unknown
            }
        case .Maestro:
            if strippedSelf.characters.count <= 16 {
                patternString = VISAPattern
            } else if strippedSelf.characters.count <= 19 {
                patternString = CUPPattern
            } else {
                throw JudoError.Unknown
            }
        default:
            if strippedSelf.characters.count <= 16 {
                patternString = VISAPattern
            } else {
                return strippedSelf
            }
        }
        
        if let patternString = patternString {
        
            var patternIndex = patternString.startIndex
            
            var retString = ""
            
            for element in strippedSelf.characters {
                if patternString.characters[patternIndex] == "X" {
                    patternIndex = advance(patternIndex, 1)
                    retString = retString + String(element)
                } else {
                    patternIndex = advance(patternIndex, 2)
                    retString = retString + " \(element)"
                }
            }
            
            return retString
        }
        
        throw JudoError.Unknown
    }
    
    
    /**
    see https://en.wikipedia.org/wiki/Bank_card_number
    This method will not do any validation - just a check for numbers from at least 1 character and return an assumption about what the card might be
    
    - Parameter cardNumber: the cardnumber to check for
    
    - Returns: CardNetwork object
    */
    func cardNetwork() -> CardNetwork {
        
        let strippedSelf = self.stringByReplacingOccurrencesOfString(" ", withString: "")
        
        // Card Networks that only have one prefix
        switch self {
        case _ where strippedSelf.beginsWith("1"):
            return .UATP
        case _ where strippedSelf.beginsWith("4"):
            return .Visa(.Unknown)
        case _ where strippedSelf.beginsWith("62"):
            return .ChinaUnionPay
        case _ where strippedSelf.beginsWith("636"):
            return .InterPayment
        case _ where strippedSelf.beginsWith("5019"):
            return .Dankort
        default:
            break
        }
        
        
        // Card Networks with multiple different prefix
        // AMEX begins with 34 & 37
        for prefix in ["34", "37"] {
            if strippedSelf.beginsWith(prefix) {
                return .AMEX
            }
        }
        
        // MasterCard begins with 51 - 55
        // new MasterCard range starting in 2016: 2221-2720
        for prefix in masterCardPrefixes {
            if strippedSelf.beginsWith(prefix) {
                return .MasterCard(.Unknown)
            }
        }
        
        // Maestro has 50, 56-69
        for prefix in maestroPrefixes {
            if strippedSelf.beginsWith(prefix) {
                return .Maestro
            }
        }
        
        // Diners Club 300-305 / 309 & 36, 38, 39
        for prefix in dinersClubPrefixes {
            if strippedSelf.beginsWith(prefix) {
                return .DinersClub
            }
        }
        
        // Discover 644-649
        for prefix in discoverPrefixes {
            if strippedSelf.beginsWith(prefix) {
                return .Discover
            }
        }
        
        // InstaPayment
        for prefix in instaPaymentPrefixes {
            if strippedSelf.beginsWith(prefix) {
                return .InstaPayment
            }
        }
        
        // JCB 3528-3589
        for prefix in JCBPrefixes {
            if strippedSelf.beginsWith(prefix) {
                return .JCB
            }
        }
        
        // none of the patterns did match
        return .Unknown
    }
    
    
    /**
    check if the string is representing a valid credit card number
    
    - Returns: true if the string is a valid credit card number
    */
    func isCardNumberValid() -> Bool {
        
        let network = self.cardNetwork()
        let strippedSelf = self.stringByReplacingOccurrencesOfString(" ", withString: "")
        
        if strippedSelf.isLuhnValid() {
            let strippedSelfCount = strippedSelf.characters.count
            
            switch network {
            case .UATP, .AMEX:
                return strippedSelfCount == 15
            case .Visa(.Debit), .Visa(.Credit), .Visa(.Unknown):
                return strippedSelfCount == 13 || strippedSelfCount == 16
            case .MasterCard(.Debit), .MasterCard(.Credit), .MasterCard(.Unknown), .Dankort, .JCB, .InstaPayment, .Discover:
                return strippedSelfCount == 16
            case .Maestro:
                return (12...19).contains(strippedSelfCount)
            case .DinersClub:
                return strippedSelfCount == 14
            case .ChinaUnionPay, .InterPayment:
                return (16...19).contains(strippedSelfCount)
            case .Unknown:
                return false
            }
        }
        return false

    }
    
    
    /**
    helper method to check wether the string begins with another given string
    
    - Parameter str: prefix string to compare
    
    - Returns: boolean indicating wether the prefix matches or not
    */
    func beginsWith (str: String) -> Bool {
        if let range = self.rangeOfString(str) {
            return range.startIndex == self.startIndex
        }
        return false
    }
    
    
    
    func isLuhnValid() -> Bool {
        guard self.isNumeric() else {
            return false
        }
        let reversedInts = self.characters.reverse().map { Int(String($0)) }
        return reversedInts.enumerate().reduce(0) { (sum, val) in
            let odd = val.index % 2 == 1
            return sum + (odd ? (val.element! == 9 ? 9 : (val.element! * 2) % 9) : val.element!)
            } % 10 == 0
    }
    
    
    func isNumeric() -> Bool {
        return Double(self) != nil
    }


}