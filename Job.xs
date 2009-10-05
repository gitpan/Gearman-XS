/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "gearman_xs.h"

typedef struct gearman_job_st gearman_xs_job;

MODULE = Gearman::XS::Job    PACKAGE = Gearman::XS::Job

PROTOTYPES: ENABLE

SV *
workload(self)
    gearman_xs_job *self
  CODE:
    RETVAL= newSVpvn(gearman_job_workload(self), gearman_job_workload_size(self));
  OUTPUT:
    RETVAL

char *
handle(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_handle(self);
  OUTPUT:
    RETVAL

const char *
function_name(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_function_name(self);
  OUTPUT:
    RETVAL

const char *
unique(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_unique(self);
  OUTPUT:
    RETVAL

gearman_return_t
send_status(self, numerator, denominator)
    gearman_xs_job *self
    uint32_t numerator
    uint32_t denominator
  CODE:
    RETVAL= gearman_job_send_status(self, numerator, denominator);
  OUTPUT:
    RETVAL

gearman_return_t
send_data(self, data)
    gearman_xs_job *self
    SV * data
  CODE:
    RETVAL= gearman_job_send_data(self, SvPV_nolen(data), SvCUR(data));
  OUTPUT:
    RETVAL

gearman_return_t
send_fail(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_send_fail(self);
  OUTPUT:
    RETVAL

gearman_return_t
send_complete(self, result)
    gearman_xs_job *self
    SV * result
  CODE:
    RETVAL= gearman_job_send_complete(self, SvPV_nolen(result), SvCUR(result));
  OUTPUT:
    RETVAL

gearman_return_t
send_warning(self, warning)
    gearman_xs_job *self
    SV * warning
  CODE:
    RETVAL= gearman_job_send_warning(self, SvPV_nolen(warning), SvCUR(warning));
  OUTPUT:
    RETVAL
