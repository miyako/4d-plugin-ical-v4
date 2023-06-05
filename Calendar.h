/*
 * Calendar.h
 */

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>


@class CalendarApplication, CalendarDocument, CalendarWindow, CalendarCalendar, CalendarDisplayAlarm, CalendarMailAlarm, CalendarSoundAlarm, CalendarOpenFileAlarm, CalendarAttendee, CalendarEvent;

enum CalendarSaveOptions {
	CalendarSaveOptionsYes = 'yes ' /* Save the file. */,
	CalendarSaveOptionsNo = 'no  ' /* Do not save the file. */,
	CalendarSaveOptionsAsk = 'ask ' /* Ask the user whether or not to save the file. */
};
typedef enum CalendarSaveOptions CalendarSaveOptions;

enum CalendarPrintingErrorHandling {
	CalendarPrintingErrorHandlingStandard = 'lwst' /* Standard PostScript error handling */,
	CalendarPrintingErrorHandlingDetailed = 'lwdt' /* print a detailed report of PostScript errors */
};
typedef enum CalendarPrintingErrorHandling CalendarPrintingErrorHandling;

enum CalendarParticipationStatus {
	CalendarParticipationStatusUnknown = 'E6na' /* No anwser yet */,
	CalendarParticipationStatusAccepted = 'E6ap' /* Invitation has been accepted */,
	CalendarParticipationStatusDeclined = 'E6dp' /* Invitation has been declined */,
	CalendarParticipationStatusTentative = 'E6tp' /* Invitation has been tentatively accepted */
};
typedef enum CalendarParticipationStatus CalendarParticipationStatus;

enum CalendarEventStatus {
	CalendarEventStatusCancelled = 'E4ca' /* A cancelled event */,
	CalendarEventStatusConfirmed = 'E4cn' /* A confirmed event */,
	CalendarEventStatusNone = 'E4no' /* An event without status */,
	CalendarEventStatusTentative = 'E4te' /* A tentative event */
};
typedef enum CalendarEventStatus CalendarEventStatus;

enum CalendarCalendarPriority {
	CalendarCalendarPriorityNoPriority = 'tdp0' /* No priority */,
	CalendarCalendarPriorityLowPriority = 'tdp9' /* Low priority */,
	CalendarCalendarPriorityMediumPriority = 'tdp5' /* Medium priority */,
	CalendarCalendarPriorityHighPriority = 'tdp1' /* High priority */
};
typedef enum CalendarCalendarPriority CalendarCalendarPriority;

enum CalendarViewType {
	CalendarViewTypeDayView = 'E5da' /* The iCal day view */,
	CalendarViewTypeWeekView = 'E5we' /* The iCal week view */,
	CalendarViewTypeMonthView = 'E5mo' /* The iCal month view */
};
typedef enum CalendarViewType CalendarViewType;

@protocol CalendarGenericMethods

- (void) closeSaving:(CalendarSaveOptions)saving savingIn:(NSURL *)savingIn;  // Close a document.
- (void) printWithProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy an object.
- (void) moveTo:(SBObject *)to;  // Move an object to a new location.
- (void) show;  // Show the event or to-do in the calendar window

@end



/*
 * Standard Suite
 */

// The application's top-level scripting object.
@interface CalendarApplication : SBApplication

- (SBElementArray<CalendarDocument *> *) documents;
- (SBElementArray<CalendarWindow *> *) windows;

@property (copy, readonly) NSString *name;  // The name of the application.
@property (readonly) BOOL frontmost;  // Is this the active application?
@property (copy, readonly) NSString *version;  // The version number of the application.

- (id) open:(id)x;  // Open a document.
- (void) print:(id)x withProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) quitSaving:(CalendarSaveOptions)saving;  // Quit the application.
- (BOOL) exists:(id)x;  // Verify that an object exists.
- (void) reloadCalendars;  // Tell the application to reload all calendar files contents
- (void) switchViewTo:(CalendarViewType)to;  // Show calendar on the given view
- (void) viewCalendarAt:(NSDate *)at;  // Show calendar on the given date
- (void) GetURL:(NSString *)x;  // Subscribe to a remote calendar through a webcal or http URL

@end

// A document.
@interface CalendarDocument : SBObject <CalendarGenericMethods>

@property (copy, readonly) NSString *name;  // Its name.
@property (readonly) BOOL modified;  // Has it been modified since the last save?
@property (copy, readonly) NSURL *file;  // Its location on disk, if it has one.


@end

// A window.
@interface CalendarWindow : SBObject <CalendarGenericMethods>

@property (copy, readonly) NSString *name;  // The title of the window.
- (NSInteger) id;  // The unique identifier of the window.
@property NSInteger index;  // The index of the window, ordered front to back.
@property NSRect bounds;  // The bounding rectangle of the window.
@property (readonly) BOOL closeable;  // Does the window have a close button?
@property (readonly) BOOL miniaturizable;  // Does the window have a minimize button?
@property BOOL miniaturized;  // Is the window minimized right now?
@property (readonly) BOOL resizable;  // Can the window be resized?
@property BOOL visible;  // Is the window visible right now?
@property (readonly) BOOL zoomable;  // Does the window have a zoom button?
@property BOOL zoomed;  // Is the window zoomed right now?
@property (copy, readonly) CalendarDocument *document;  // The document whose contents are displayed in the window.


@end



/*
 * iCal
 */

// This class represents iCal.
@interface CalendarApplication (ICal)

- (SBElementArray<CalendarCalendar *> *) calendars;

@end

// This class represents a calendar.
@interface CalendarCalendar : SBObject <CalendarGenericMethods>

- (SBElementArray<CalendarEvent *> *) events;

@property (copy) NSString *name;  // This is the calendar title.
@property (copy) NSColor *color;  // The calendar color.
@property (copy, readonly) NSString *calendarIdentifier;  // An unique calendar key
@property (readonly) BOOL writable;  // This is the calendar title.
@property (copy) NSString *objectDescription;  // This is the calendar description.


@end

// This class represents a message alarm.
@interface CalendarDisplayAlarm : SBObject <CalendarGenericMethods>

@property NSInteger triggerInterval;  // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
@property (copy) NSDate *triggerDate;  // An absolute alarm date.


@end

// This class represents a mail alarm.
@interface CalendarMailAlarm : SBObject <CalendarGenericMethods>

@property NSInteger triggerInterval;  // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
@property (copy) NSDate *triggerDate;  // An absolute alarm date.


@end

// This class represents a sound alarm.
@interface CalendarSoundAlarm : SBObject <CalendarGenericMethods>

@property NSInteger triggerInterval;  // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
@property (copy) NSDate *triggerDate;  // An absolute alarm date.
@property (copy) NSString *soundName;  // The system sound name to be used for the alarm
@property (copy) NSString *soundFile;  // The (POSIX) path to the sound file to be used for the alarm


@end

// This class represents an 'open file' alarm. Starting with OS X 10.14, it is not possible to create new open file alarms or view URLs for existing open file alarms. Trying to save or modify an open file alarm will result in a save error. Editing other aspects of events or reminders that have existing open file alarms is allowed as long as the alarm isn't modified.
@interface CalendarOpenFileAlarm : SBObject <CalendarGenericMethods>

@property NSInteger triggerInterval;  // The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).
@property (copy) NSDate *triggerDate;  // An absolute alarm date.
@property (copy) NSString *filepath;  // The (POSIX) path to be opened by the alarm


@end

// This class represents a attendee.
@interface CalendarAttendee : SBObject <CalendarGenericMethods>

@property (copy, readonly) NSString *displayName;  // The first and last name of the attendee.
@property (copy, readonly) NSString *email;  // e-mail of the attendee.
@property (readonly) CalendarParticipationStatus participationStatus;  // The invitation status for the attendee.


@end

// This class represents an event.
@interface CalendarEvent : SBObject <CalendarGenericMethods>

- (SBElementArray<CalendarAttendee *> *) attendees;
- (SBElementArray<CalendarDisplayAlarm *> *) displayAlarms;
- (SBElementArray<CalendarMailAlarm *> *) mailAlarms;
- (SBElementArray<CalendarOpenFileAlarm *> *) openFileAlarms;
- (SBElementArray<CalendarSoundAlarm *> *) soundAlarms;

@property (copy) NSString *objectDescription;  // The events notes.
@property (copy) NSDate *startDate;  // The event start date.
@property (copy) NSDate *endDate;  // The event end date.
@property BOOL alldayEvent;  // True if the event is an all-day event
@property (copy) NSString *recurrence;  // The iCalendar (RFC 2445) string describing the event recurrence, if defined
@property (readonly) NSInteger sequence;  // The event version.
@property (copy) NSDate *stampDate;  // The event modification date.
@property (copy) NSArray<NSDate *> *excludedDates;  // The exception dates.
@property CalendarEventStatus status;  // The event status.
@property (copy) NSString *summary;  // This is the event summary.
@property (copy) NSString *location;  // This is the event location.
@property (copy, readonly) NSString *uid;  // An unique event key.
@property (copy) NSString *url;  // The URL associated to the event.


@end

