//
//  KlistUtil.swift
//  NoMAD
//
//  Created by Joel Rennich on 7/18/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

import Foundation
import GSS
import NoMADPRIVATE

// Class to parse klist -v --json and return all tickets and times

// TODO: Handle multiple caches at the same time
// TODO: pack everything into one structure

public struct Ticket {
    var expired: Bool
    var expires: Date
    var defaultCache: Bool
    var principal: String
    var krb5Cache: krb5_ccache?
    var GSSItem: GSSItemRef?
}

// singleton for the class

public let klistUtil = KlistUtil()

public class KlistUtil {

    let dateFormatter = DateFormatter()
    public lazy var tickets = [String: Ticket]()
    public var defaultPrincipal: String?
    public var defaultExpires: Date?

    init() {
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
    }

    public func returnTickets() -> [Ticket] {

        // update the tickets

        klist()

        var results = [Ticket]()
        for ticket in tickets {
            results.append(ticket.value)
        }

        return results

    }

    // convenience function to return all principals

    public func returnPrincipals() -> [String] {
        klist()
        return tickets.keys.sorted()
    }

    // convenience function to return default principal

    public func returnDefaultPrincipal() -> String {
        return defaultPrincipal ?? "No Ticket"
    }

    public func returnDefaultExpiration() -> Date? {
        return defaultExpires
    }

    public func klist() {

        let sema = DispatchSemaphore(value: 0)

        // clear the current cached tickets

        tickets.removeAll()
        defaultPrincipal = nil
        defaultExpires = nil

        // use krb5 API to get default tickets and all tickets, including expired ones

        var context: krb5_context?
        krb5_init_secure_context(&context)

        var oCache: krb5_ccache?
        _ = UnsafeMutablePointer<Any>.init(oCache)

        let cname = krb5_cc_default_name(context)
        let defaultName = String(cString: cname!).replacingOccurrences(of: "API:", with: "")

        var cursor: krb5_cccol_cursor?
        var ret: krb5_error_code?
        var minStat = OM_uint32()

        ret = krb5_cccol_cursor_new(context, &cursor)

        while ((krb5_cccol_cursor_next(context, cursor, &oCache) == 0 ) && oCache != nil) {
            let name = (String(cString: (krb5_cc_get_name(context, oCache))))
            var princ: krb5_principal?
            ret = krb5_cc_get_principal(context, oCache, &princ)
            //print(princ.debugDescription)
            var princName: UnsafeMutablePointer<Int8>?
            krb5_unparse_name(context, princ!, &princName)
            let princNameString = String(cString: princName!)
            tickets[princNameString] = Ticket(expired: true, expires: Date.distantPast, defaultCache: false, principal: princNameString, krb5Cache: oCache, GSSItem: nil)
            if name == defaultName {
                //print("Default principal: " + princNameString )
                defaultPrincipal = princNameString
                defaultExpires = Date.distantPast
                tickets[princNameString]?.defaultCache = true
            }
        }

        // now move to GSS APIs to get expiration times
        // TODO: move this all to GSS APIs when the GSS API functionality is there

        gss_iter_creds(&minStat, 0, nil, { _, cred in

            _ = OM_uint32()
            _ = gss_buffer_desc()

            if cred != nil {
                let name = GSSCredentialCopyName(cred!)
                if name != nil {
                    let displayName = GSSNameCreateDisplayString(name!)!
                    let displayNameString = String(describing: displayName.takeRetainedValue())
                    //print(displayNameString)
                    let lifetime = GSSCredentialGetLifetime(cred!)
                    let expiretime = Date().addingTimeInterval(TimeInterval(lifetime))
                    //print(self.tickets[displayNameString])
                    self.tickets[displayNameString]?.expired = false
                    self.tickets[displayNameString]?.expires = expiretime
                    self.tickets[displayNameString]?.GSSItem = cred
                    if self.defaultPrincipal == displayNameString {
                        self.defaultExpires = expiretime
                    }
                } else {
                    print("Expired credential - ignoring.")
                }
            }
            sema.signal()
            myLogger.logit(.debug, message: "Tickets: " + self.tickets.keys.joined(separator: ", "))
        })
        sema.wait()
        //return tickets

        // clean up any expired tickets

        let ticks = tickets

        tickets.removeAll()

        for tick in ticks {
            if !tick.value.expired {
                // ticket is not expired add it back
                tickets[tick.value.principal] = tick.value
            }
        }
        //print(tickets)
    }

    // function to delete a kerb ticket

    public func kdestroy(princ: String = "" ) {

        var name = ""

        if princ == "" {
            name = defaultPrincipal!
        } else {
            name = princ
        }

        myLogger.logit(.debug, message: "Destroying ticket for: " + princ)
        // update this for GSSAPI when the functionality is there

        var context: krb5_context?
        krb5_init_secure_context(&context)

        krb5_cc_destroy(context, tickets[name]?.krb5Cache)
    }

    // function to switch the default cache

    public func kswitch(princ: String = "" ) {

        var name = ""
        var kerbPrinc: krb5_principal?
        var cache: krb5_ccache?

        if princ == "" {
            name = defaultPrincipal!
        } else {
            name = princ
        }

        var nameInt = Int8(name)

        myLogger.logit(.debug, message: "Switching ticket for: " + princ)
        // update this for GSSAPI when the functionality is there

        var context: krb5_context?
        krb5_init_secure_context(&context)

        krb5_parse_name(context!, &nameInt!, &kerbPrinc)
        krb5_cc_cache_match(context, kerbPrinc, &cache)
        // krb5_cc_set_default_name
    }
}
