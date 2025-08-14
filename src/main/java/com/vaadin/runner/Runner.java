package com.vaadin.runner;

import com.vaadin.parameter.PitArguments;

public interface Runner {

    boolean isApplicable(PitArguments arguments);
    void run(PitArguments arguments);

}
