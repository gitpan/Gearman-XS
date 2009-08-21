/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "gearman_xs.h"

typedef struct gearman_task_st gearman_xs_task;

MODULE = Gearman::XS::Task    PACKAGE = Gearman::XS::Task

PROTOTYPES: ENABLE

const char *
job_handle(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_job_handle(self);
  OUTPUT:
    RETVAL

SV *
data(self)
    gearman_xs_task *self
  CODE:
    RETVAL= newSVpvn(gearman_task_data(self), gearman_task_data_size(self));
  OUTPUT:
    RETVAL

int
data_size(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_data_size(self);
  OUTPUT:
    RETVAL

const char *
function(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_function(self);
  OUTPUT:
    RETVAL

uint32_t
numerator(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_numerator(self);
  OUTPUT:
    RETVAL

uint32_t
denominator(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_denominator(self);
  OUTPUT:
    RETVAL

const char *
uuid(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_uuid(self);
  OUTPUT:
    RETVAL
