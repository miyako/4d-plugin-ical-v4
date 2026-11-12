// Ownership regressions for the iCal plugin's 4D variable/object handling.
// Unity build of the real plugin source (so its file-static listener functions
// are reachable) plus the real SDK and support/4DPlugin-JSON.cpp, running
// against tests/ownership/fake_engine instead of 4D. No real EventKit store or
// calendar data is touched: events and stores are fake NSObjects.
// Usage: harness [expected-failure ...]  (names of tests that must fail)
#include "4DPlugin-iCal.cpp"
#include "fake_engine.h"
#include <cstdio>
#include <functional>
#include <set>
#include <string>

using namespace fake4d;

@interface FakeEvent : NSObject
@property (retain) NSDate *startDate;
@property (retain) NSDate *endDate;
@property (copy) NSString *title;
@property (copy) NSString *location;
@property (copy) NSString *notes;
@property (retain) NSURL *URL;
@property (assign) BOOL allDay;
@property (retain) NSMutableArray *rules;
@end

@implementation FakeEvent
- (id)init { if ((self = [super init])) _rules = [[NSMutableArray alloc] init]; return self; }
- (void)dealloc {
    [_startDate release]; [_endDate release]; [_title release]; [_location release];
    [_notes release]; [_URL release]; [_rules release];
    [super dealloc];
}
- (BOOL)hasRecurrenceRules { return [_rules count] != 0; }
- (NSArray *)recurrenceRules { return _rules; }
- (void)addRecurrenceRule:(EKRecurrenceRule *)rule { [_rules addObject:rule]; }
- (void)removeRecurrenceRule:(EKRecurrenceRule *)rule { [_rules removeObject:rule]; }
@end

@interface FakeStore : NSObject
@property (assign) int lookups;
@end

@implementation FakeStore
- (EKCalendar *)calendarWithIdentifier:(NSString *)uid { _lookups++; return nil; }
- (NSArray *)calendarsForEntityType:(EKEntityType)type { _lookups++; return @[]; }
@end

static std::vector<std::string> gFailures;
#define CHECK(cond) do { if (!(cond)) gFailures.push_back(#cond); } while (0)

static Obj *list(std::initializer_list<double> reals, const char *text) {
    Obj *c = new_object(true);
    for (double r : reals) push_real(c, r);
    if (text) push_string(c, text);
    return c;
}

static void attach(Obj *parent, const char *key, Obj *child) { put_ref(parent, key, child); release(child); }

static Obj *event_options() {
    Obj *opts = new_object();
    put_date(opts, "startDate", 1, 4, 2024);
    put_date(opts, "endDate", 2, 4, 2024);
    return opts;
}

static void listener(const char *method) {
    iCalv4::notifications.push_back(CUTF8String((const uint8_t *)"{}"));
    CUTF16String m;
    for (const char *p = method; *p; ++p) m.push_back((PA_Unichar)*p);
    iCalv4::LISTENER_METHOD = m;
    listenerLoopExecuteMethod();
    iCalv4::LISTENER_METHOD.clear();
}

struct Test { const char *name; std::function<void()> body; };

static const Test kTests[] = {
    // --- LIVE: support/4DPlugin-JSON.cpp getters (QUERY EVENT, Create/Set/Get/Remove event & calendar) ---
    {"live_ob_get_s_released", [] {
        Obj *o = new_object();
        put_string(o, "k", "hello");
        CUTF8String s;
        CHECK(ob_get_s(o, L"k", &s));
        CHECK(s == CUTF8String((const uint8_t *)"hello"));
        release(o);
    }},
    {"live_ob_get_v_released", [] {
        Obj *o = new_object();
        put_string(o, "uid", "abc");
        @autoreleasepool { CHECK([ob_get_v(o, L"uid") isEqualToString:@"abc"]); }
        release(o);
    }},
    {"live_ob_get_o_borrowed", [] {
        Obj *o = new_object(), *c = new_object();
        put_ref(o, "calendar", c);
        PA_ObjectRef got = ob_get_o(o, L"calendar");
        CHECK(got == (PA_ObjectRef)c);
        CHECK(refcount(c) == 2); // test + parent: the parent keeps the borrowed ref alive
        release(c); release(o);
        CHECK(refcount(c) == 0);
    }},
    {"live_ob_get_c_borrowed", [] {
        Obj *o = new_object(), *c = new_object(true);
        put_ref(o, "calendars", c);
        PA_CollectionRef got = ob_get_c(o, L"calendars");
        CHECK(got == (PA_CollectionRef)c);
        CHECK(refcount(c) == 2);
        release(c); release(o);
        CHECK(refcount(c) == 0);
    }},
    {"live_ob_get_b_n_d_nonmatching_released", [] {
        Obj *o = new_object();
        put_string(o, "isAllDay", "yes"); put_string(o, "n", "1"); put_string(o, "startDate", "today");
        CHECK(!ob_get_b(o, L"isAllDay"));
        CHECK(ob_get_n(o, L"n") == 0.0);
        @autoreleasepool { CHECK(ob_get_d(o, L"startDate") == nil); }
        release(o);
    }},
    {"live_ob_get_o_c_nonmatching_released", [] {
        Obj *o = new_object();
        put_string(o, "calendar", "x");
        CHECK(ob_get_o(o, L"calendar") == nullptr);
        CHECK(ob_get_c(o, L"calendar") == nullptr);
        release(o);
    }},
    // --- LIVE: 4DPlugin-iCal.cpp collection element reads ---
    {"live_ob_get_calendars_elements_released", [] {
        Obj *opts = new_object(), *cals = new_object(true);
        Obj *byUid = new_object(), *byTitle = new_object();
        put_string(byUid, "uid", "u1"); put_string(byTitle, "title", "Work");
        push_ref(cals, byUid); push_ref(cals, byTitle); push_string(cals, "not an object");
        attach(opts, "calendars", cals);
        FakeStore *store = [[FakeStore alloc] init];
        @autoreleasepool {
            NSArray *found = ob_get_calendars((PA_ObjectRef)opts, (EKEventStore *)store);
            CHECK(found != nil && [found count] == 0);
            [found release];
        }
        CHECK(store.lookups == 2);
        [store release];
        CHECK(refcount(byUid) == 2 && refcount(byTitle) == 2);
        release(byUid); release(byTitle); release(opts);
        CHECK(refcount(byUid) == 0 && refcount(byTitle) == 0);
    }},
    {"live_recurrence_elements_released", [] {
        Obj *opts = event_options(), *rule = new_object();
        put_string(opts, "title", "t");
        put_real(rule, "recurrenceType", EKRecurrenceFrequencyWeekly);
        put_real(rule, "recurrenceInterval", 1);
        // daysOfTheWeek gets no Real: the plugin hands EventKit NSNumbers where it
        // expects EKRecurrenceDayOfWeek, which throws (separate, non-ownership bug).
        attach(rule, "daysOfTheWeek", list({}, "2"));
        const char *keys[] = {"daysOfTheMonth", "monthsOfTheYear", "weeksOfTheYear",
                              "daysOfTheYear", "setPositions"};
        for (const char *k : keys) attach(rule, k, list({1}, "2"));
        attach(opts, "recurrenceRule", rule);
        Obj *status = new_object();
        FakeEvent *ev = [[FakeEvent alloc] init];
        @autoreleasepool { ob_set_event_prop((PA_ObjectRef)status, (PA_ObjectRef)opts, (EKEvent *)ev); }
        CHECK([ev.rules count] == 1);
        CHECK([ev.title isEqualToString:@"t"]);
        [ev release];
        release(status); release(opts);
    }},
    {"live_element_get_error_skipped", [] {
        Obj *opts = new_object(), *cals = new_object(true), *byUid = new_object();
        put_string(byUid, "uid", "u1");
        push_ref(cals, byUid); push_ref(cals, byUid);
        attach(opts, "calendars", cals);
        FakeStore *store = [[FakeStore alloc] init];
        fail_next_gets(2, true); // both element reads fail; poisoned values must be skipped, not cleared
        @autoreleasepool { [ob_get_calendars((PA_ObjectRef)opts, (EKEventStore *)store) release]; }
        CHECK(store.lookups == 0);
        [store release];
        Obj *ev_opts = event_options(), *rule = new_object(), *status = new_object();
        put_real(rule, "recurrenceInterval", 1);
        attach(rule, "daysOfTheMonth", list({1, 2}, nullptr));
        attach(ev_opts, "recurrenceRule", rule);
        FakeEvent *ev = [[FakeEvent alloc] init];
        fail_next_gets(2, true);
        @autoreleasepool { ob_set_event_prop((PA_ObjectRef)status, (PA_ObjectRef)ev_opts, (EKEvent *)ev); }
        CHECK([ev.rules count] == 1);
        [ev release];
        CHECK(refcount(byUid) == 3);
        release(byUid); release(opts); release(status); release(ev_opts);
        CHECK(refcount(byUid) == 0);
    }},
    // --- LIVE: setters that seed an empty owned string before a shallow set ---
    {"live_ob_set_s_wide_no_leak", [] {
        Obj *o = new_object();
        ob_set_s((PA_ObjectRef)o, L"errorMessage", "invalid event");
        std::string got;
        CHECK(get_string(o, "errorMessage", &got) && got == "invalid event");
        release(o);
    }},
    {"live_ob_set_v_u_no_leak", [] {
        Obj *o = new_object();
        @autoreleasepool {
            ob_set_v((PA_ObjectRef)o, L"title", @"x");
            ob_set_u((PA_ObjectRef)o, L"url", [NSURL URLWithString:@"https://example.com/"]);
        }
        std::string got;
        CHECK(get_string(o, "title", &got) && got == "x");
        CHECK(get_string(o, "url", &got) && got == "https://example.com/");
        release(o);
    }},
    {"live_listener_execute_method_no_leak", [] {
        set_method("other", 7, nullptr); // "cb" has no ID: EXECUTE METHOD (1007) path
        listener("cb");
        CHECK(method_calls() == 1);
        CHECK(last_execute_method_name() == "cb");
    }},
    // --- HARDENING: unproven in 4D (SDK pre-sets the result to Undefined) ---
    {"hardening_listener_byid_result_released", [] {
        set_method("cb", 7, "returned"); // engine hands back an owned return value
        listener("cb");
        CHECK(method_calls() == 1);
    }},
    // --- DORMANT: helpers with no consumer in this plugin ---
    {"dormant_ob_set_s_narrow_no_leak", [] {
        Obj *o = new_object();
        ob_set_s((PA_ObjectRef)o, "k", "v");
        std::string got;
        CHECK(get_string(o, "k", &got) && got == "v");
        release(o);
    }},
    {"dormant_ob_set_a_no_leak", [] {
        Obj *o = new_object();
        CUTF16String u16;
        u16.push_back('w');
        ob_set_a((PA_ObjectRef)o, L"a", L"z");
        ob_set_a((PA_ObjectRef)o, L"b", &u16);
        std::string got;
        CHECK(get_string(o, "a", &got) && got == "z");
        CHECK(get_string(o, "b", &got) && got == "w");
        release(o);
    }},
    {"dormant_ob_set_p_no_leak", [] {
        Obj *o = new_object();
        PA_Picture p = PA_CreatePicture(nullptr, 0);
        ob_set_p((PA_ObjectRef)o, L"p", p); // consumes p, like ob_set_o/ob_set_c
        CHECK(has_picture(o, "p"));
        release(o);
    }},
    // --- controls: must pass before and after ---
    {"control_getters_error_not_cleared", [] {
        Obj *o = new_object();
        put_string(o, "s", "x"); put_real(o, "n", 1); put_bool(o, "b", true); put_date(o, "d", 1, 1, 2024);
        CUTF8String s;
        fail_next_gets(1); ob_get_a(o, L"s", &s);
        fail_next_gets(1); CHECK(ob_get_n(o, L"n") == 0.0);
        fail_next_gets(1); CHECK(!ob_get_b(o, L"b"));
        fail_next_gets(1); CHECK(ob_get_o(o, L"s") == nullptr);
        fail_next_gets(1); CHECK(ob_get_c(o, L"s") == nullptr);
        @autoreleasepool {
            fail_next_gets(1); CHECK(ob_get_v(o, L"s") == nil);
            fail_next_gets(1); CHECK(ob_get_d(o, L"d") == nil);
        }
        release(o);
    }},
    {"control_scalar_getters", [] {
        Obj *o = new_object();
        put_real(o, "n", 2.5); put_bool(o, "b", true); put_date(o, "d", 3, 4, 2024);
        CHECK(ob_get_n(o, L"n") == 2.5);
        CHECK(ob_get_b(o, L"b"));
        CHECK(ob_get_n(o, L"missing") == 0.0);
        CHECK(ob_is_defined(o, L"n"));
        CHECK(!ob_is_defined(o, L"missing"));
        @autoreleasepool {
            NSDate *d = ob_get_d(o, L"d");
            CHECK(d != nil);
            if (d) {
                NSDateComponents *c = [[NSCalendar currentCalendar]
                    components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:d];
                CHECK(c.year == 2024 && c.month == 4 && c.day == 3);
            }
        }
        release(o);
    }},
    {"control_consuming_setters", [] {
        Obj *o = new_object(), *child = new_object(), *coll = new_object(true);
        ob_set_n(o, L"n", 1); ob_set_b(o, L"t", true); ob_set_0(o, L"z"); ob_set_i(o, L"i", 3);
        @autoreleasepool { ob_set_d(o, L"d", [NSDate date]); }
        ob_set_o(o, L"o", (PA_ObjectRef)child);      // consumes the caller's reference
        ob_set_c(o, L"c", (PA_CollectionRef)coll);   // consumes the caller's reference
        CHECK(refcount(child) == 1 && refcount(coll) == 1);
        release(o);
        CHECK(refcount(child) == 0 && refcount(coll) == 0);
    }},
    {"control_listener_byid_no_result", [] {
        set_method("cb", 7, nullptr);
        listener("cb");
        CHECK(method_calls() == 1);
    }},
    {"control_listener_no_method", [] {
        listener("");
        CHECK(method_calls() == 0);
    }},
    {"control_event_prop_without_recurrence", [] {
        Obj *opts = event_options(), *status = new_object();
        put_bool(opts, "isAllDay", true);
        FakeEvent *ev = [[FakeEvent alloc] init];
        @autoreleasepool { ob_set_event_prop((PA_ObjectRef)status, (PA_ObjectRef)opts, (EKEvent *)ev); }
        CHECK(ev.allDay);
        CHECK([ev.rules count] == 0);
        [ev release];
        release(status); release(opts);
    }},
};

int main(int argc, char **argv) {
    install();
    std::set<std::string> expected(argv + 1, argv + argc);
    int unexpected = 0, passed = 0, xfailed = 0;
    for (const Test &t : kTests) {
        reset();
        gFailures.clear();
        size_t strings = live_strings(), handles = live_handles(), objects = live_objects(),
               pictures = live_pictures();
        t.body();
        for (auto &v : violations()) gFailures.push_back("engine: " + v);
        if (live_strings() != strings)
            gFailures.push_back("leaked strings: " + std::to_string((long)(live_strings() - strings)));
        if (live_handles() != handles) gFailures.push_back("leaked handles");
        if (live_objects() != objects)
            gFailures.push_back("leaked objects: " + std::to_string((long)(live_objects() - objects)));
        if (live_pictures() != pictures)
            gFailures.push_back("leaked pictures: " + std::to_string((long)(live_pictures() - pictures)));
        bool failed = !gFailures.empty();
        bool want = expected.erase(t.name) > 0;
        const char *verdict = failed ? (want ? "XFAIL" : "FAIL") : (want ? "XPASS" : "PASS");
        printf("%-5s %s\n", verdict, t.name);
        for (auto &f : gFailures) printf("      %s\n", f.c_str());
        if (failed != want) unexpected++;
        else if (failed) xfailed++;
        else passed++;
    }
    for (auto &name : expected) { printf("UNKNOWN expected failure %s\n", name.c_str()); unexpected++; }
    printf("passed=%d xfailed=%d unexpected=%d\n", passed, xfailed, unexpected);
    printf("%s\n", unexpected ? "RESULT: UNEXPECTED" : "RESULT: OK");
    return unexpected ? 1 : 0;
}
