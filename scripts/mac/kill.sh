#!/bin/bash
pkill -x RecordApp 2>/dev/null && echo "RecordApp stopped." || echo "RecordApp was not running."
