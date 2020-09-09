#!/bin/bash

echo "Erasing states"
rm ./data/state/*.state

echo "Erasing log"
rm ./data/event/*.log

echo "Done"
