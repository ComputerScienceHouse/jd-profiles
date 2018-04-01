var gulp = require('gulp');
var exec = require('child_process').exec;

var pylintTask = function (cb) {
    exec('pylint Profiles', function (err, stdout, stderr) {
        console.log(stdout);
        console.log(stderr);
        cb(err);
    });
}

gulp.task('pylint', pylintTask);
