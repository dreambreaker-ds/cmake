include(CheckFunctionExists)

check_function_exists(epoll_ctl HAVE_EPOLL)
check_function_exists(timerfd_create HAVE_TIMERFD)
check_function_exists(kqueue HAVE_KQUEUE)

# This should hopefully always be true on every target platform. Best
# to check for it anyways.
check_function_exists(poll HAVE_POLL)

# We have to either have kqueue or timerfd, or the IO Loop won't build.
# Epoll isn't required because it can fall back to regular poll(), but
# timerfd is necessary for timers. Thankfully timerfd was introduced in
# kernel 2.6.25 and glibc 2.8 so it should be available everywhere.
if ( NOT HAVE_KQUEUE AND NOT HAVE_TIMERFD )
  message(FATAL_ERROR "Either kqueue or timerfd support are required")
endif()

set(USE_EPOLL_BACKEND false)
set(USE_KQUEUE_BACKEND false)
set(USE_POLL_BACKEND false)

if ( ZEEK_POLL_BACKEND STREQUAL "epoll" )

  if ( NOT HAVE_EPOLL )
    message(FATAL_ERROR "epoll backend was requested, but epoll_ctl() was not found on the system")
  elseif ( NOT HAVE_TIMERFD )
    message(FATAL_ERROR "epoll backend was requested, but timerfd_create() was not found on the system")
  endif()

  set(USE_EPOLL_BACKEND true)

elseif ( ZEEK_POLL_BACKEND STREQUAL "kqueue" )

  if ( NOT HAVE_KQUEUE )
    message(FATAL_ERROR "kqueue backend was requested, but kqueue() was not found on the system")
  endif()

  set(USE_KQUEUE_BACKEND true)

elseif ( ZEEK_POLL_BACKEND STREQUAL "poll" )

  if ( NOT HAVE_TIMERFD )
    message(FATAL_ERROR "poll backend was requested, but timerfd_create() was not found on the system")
  elseif ( NOT HAVE_POLL )
    message(FATAL_ERROR "poll backend was requested, but poll() was not found on the system")
  endif()

  set(USE_POLL_BACKEND true)

elseif ( ZEEK_POLL_BACKEND STREQUAL "" )

  if ( HAVE_KQUEUE )
    set(USE_KQUEUE_BACKEND true)
  elseif ( HAVE_EPOLL )
    set(USE_EPOLL_BACKEND true)
  elseif ( HAVE_POLL )
    set(USE_POLL_BACKEND true)
  else()
    message(FATAL_ERROR "Failed to find any valid poll backends")
  endif()

else()
  message(FATAL_ERROR "Unknown poll backend '${ZEEK_POLL_BACKEND}' was requested")

endif()
