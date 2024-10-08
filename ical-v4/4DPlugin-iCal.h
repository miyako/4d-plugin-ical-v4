/* --------------------------------------------------------------------------------
 #
 #	4DPlugin-iCal.h
 #	source generated by 4D Plugin Wizard
 #	Project : iCal
 #	author : miyako
 #	2020/03/17
 #  
 # --------------------------------------------------------------------------------*/

#ifndef PLUGIN_ICAL_H
#define PLUGIN_ICAL_H

#include "4DPluginAPI.h"
#include "4DPlugin-JSON.h"

#include <mutex>

#import <Cocoa/Cocoa.h>
#import <EventKit/EventKit.h>
#import <Security/Security.h>

#include "C_TEXT.h"

#pragma mark -

void iCal_Request_permisson(PA_PluginParameters params);

typedef enum {
    
    request_permission_unknown = 0,
    request_permission_authorized = 1,
    request_permission_not_determined = 2,
    request_permission_denied = 3,
    request_permission_restricted = 4
    
}request_permission_t;

// --- Calendar Store
void iCal_QUERY_EVENT(PA_PluginParameters params);
void iCal_GET_CALENDAR_LIST(PA_PluginParameters params);

// --- Calendar
void iCal_Create_calendar(PA_PluginParameters params);
void iCal_Set_calendar_property(PA_PluginParameters params);
void iCal_Get_calendar_property(PA_PluginParameters params);
void iCal_Remove_calendar(PA_PluginParameters params);

void iCal_Get_default_calendar(PA_PluginParameters params);

// --- Event
void iCal_Create_event(PA_PluginParameters params);
void iCal_Set_event_property(PA_PluginParameters params);
void iCal_Get_event_property(PA_PluginParameters params);
void iCal_Remove_event(PA_PluginParameters params);

static void iCal_KILL_WORKER(PA_PluginParameters params);

static void iCal_Set_notification_method(PA_PluginParameters params);
static void iCal_Get_notification_method(PA_PluginParameters params);

//static void listenerInit(void);
static void listenerLoop(void);
static void listenerLoopStart(void);
static void listenerLoopFinish(void);
static void listenerLoopExecute(void);
static void listenerLoopExecuteMethod(void);

typedef PA_long32 process_number_t;
typedef PA_long32 process_stack_size_t;
typedef PA_long32 method_id_t;
typedef PA_Unichar* process_name_t;

static void listener_start(EKEventStore *eventStore);

static NSString *eventForObject(NSString *objectID);

typedef enum
{
    
    notification_create = 0,
    notification_update = 1,
    notification_delete = 2
    
} notification_t;

//TODO: return in event (read only) alarms, attendees, recurrenceRule

// total 10 commands.

// removed (should be a separate utility)
/*
 iCal_TIMEZONE_LIST
 iCal_Get_timezones
 iCal_Get_timezone_info
 iCal_Get_timezone_for_offset
 iCal_Get_system_timezone
 iCal_Make_color_from_index
 */

// removed (requires scripting bridge, should be a separate solution)
/*
 iCal_Get_event_alarm
 iCal_Count_event_alarms
 iCal_Get_task_alarm
 iCal_Count_task_alarms
 iCal_Set_event_alarm
 iCal_Add_alarm_to_event
 iCal_Set_task_alarm
 iCal_Add_alarm_to_task
 iCal_Remove_event_alarm
 iCal_Remove_task_alarm
 iCal_Set_alarm_property (using scpt)
 iCal_Get_alarm_property (using scpt)
 iCal_Get_event_property (using scpt)
 iCal_SHOW_TASK
 iCal_SHOW_EVENT
 iCal_SET_VIEW
 iCal_SHOW_DATE
 iCal_Make_alarm
 */

//removed (task/reminder should be a separate solution)
/*
 iCal_Create_task
 iCal_Set_task_property
 iCal_Get_task_property
 iCal_Remove_task
 */

//removed (notification should be a separate solution)
/*
 iCal_Set_notification_method
 iCal_Get_notification_method
 */
#endif /* PLUGIN_ICAL_H */
