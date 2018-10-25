#include "tied_shape.h"

void tied_shape::draw() const {
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();

    glTranslatef(translation[0], translation[1], translation[2]);
    glRotatef(rotation[0], rotation[1], rotation[2], rotation[3]);
    glScalef(scaling[0], scaling[1], scaling[2]);

    for (const auto &group : groups) {
        group.draw();
    }

    glPopMatrix();
}
